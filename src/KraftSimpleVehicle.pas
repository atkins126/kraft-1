(******************************************************************************
 *                      VEHICLE PHYSICS FOR KRAFT PHYSICS ENGINE              *
 ******************************************************************************
 *                        Version 2023-07-02-10-26-0000                       *
 ******************************************************************************
 *                                zlib license                                *
 *============================================================================*
 *                                                                            *
 * Copyright (c) 2023-2023, Benjamin Rosseaux (benjamin@rosseaux.de)          *
 *                                                                            *
 * This software is provided 'as-is', without any express or implied          *
 * warranty. In no event will the authors be held liable for any damages      *
 * arising from the use of this software.                                     *
 *                                                                            *
 * Permission is granted to anyone to use this software for any purpose,      *
 * including commercial applications, and to alter it and redistribute it     *
 * freely, subject to the following restrictions:                             *
 *                                                                            *
 * 1. The origin of this software must not be misrepresented; you must not    *
 *    claim that you wrote the original software. If you use this software    *
 *    in a product, an acknowledgement in the product documentation would be  *
 *    appreciated but is not required.                                        *
 * 2. Altered source versions must be plainly marked as such, and must not be *
 *    misrepresented as being the original software.                          *
 * 3. This notice may not be removed or altered from any source distribution. *
 *                                                                            *
 ******************************************************************************
 *                  General guidelines for code contributors                  *
 *============================================================================*
 *                                                                            *
 * 1. Make sure you are legally allowed to make a contribution under the zlib *
 *    license.                                                                *
 * 2. The zlib license header goes at the top of each source file, with       *
 *    appropriate copyright notice.                                           *
 * 3. After a pull request, check the status of your pull request on          *
      http://github.com/BeRo1985/kraft                                        *
 * 4. Write code, which is compatible with lastest Delphi and lastest         *
 *    FreePascal versions                                                     *
 * 5. Don't use Delphi VCL, FreePascal FCL or Lazarus LCL libraries/units.    *
 * 6. No use of third-party libraries/units as possible, but if needed, make  *
 *    it out-ifdef-able                                                       *
 * 7. Try to use const when possible.                                         *
 * 8. Make sure to comment out writeln, used while debugging                  *
 * 9. Use TKraftScalar instead of float/double so that Kraft can be compiled  *
 *    as double/single precision.                                             *
 * 10. Make sure the code compiles on 32-bit and 64-bit platforms in single   *
 *     and double precision.                                                  *
 *                                                                            *
 ******************************************************************************)
unit KraftSimpleVehicle;
{$ifdef fpc}
 {$mode delphi}
 {$warnings off}
 {$hints off}
 {$define caninline}
 {$ifdef cpui386}
  {$define cpu386}
 {$endif}
 {$ifdef cpuamd64}
  {$define cpux86_64}
  {$define cpux64}
 {$else}
  {$ifdef cpux86_64}
   {$define cpuamd64}
   {$define cpux64}
  {$endif}
 {$endif}
 {$ifdef cpu386}
  {$define cpu386}
  {$asmmode intel}
  {$define canx86simd}
 {$endif}
 {$ifdef FPC_LITTLE_ENDIAN}
  {$define LITTLE_ENDIAN}
 {$else}
  {$ifdef FPC_BIG_ENDIAN}
   {$define BIG_ENDIAN}
  {$endif}
 {$endif}
 {$packset fixed}
{$else}
 {$define LITTLE_ENDIAN}
 {$ifndef cpu64}
  {$define cpu32}
 {$endif}
 {$safedivide off}
 {$optimization on}
 {$undef caninline}
 {$undef canx86simd}
 {$ifdef conditionalexpressions}
  {$if CompilerVersion>=24.0}
   {$legacyifend on}
  {$ifend}
 {$endif}
 {$ifdef ver180}
  {$define caninline}
  {$ifdef cpu386}
   {$define canx86simd}
  {$endif}
  {$finitefloat off}
 {$endif}
{$endif}
{$ifdef win32}
 {$define windows}
{$endif}
{$ifdef win64}
 {$define windows}
{$endif}
{$extendedsyntax on}
{$writeableconst on}
{$varstringchecks on}
{$typedaddress off}
{$overflowchecks off}
{$rangechecks off}
{$ifndef fpc}
{$realcompatibility off}
{$endif}
{$openstrings on}
{$longstrings on}
{$booleval off}
{$typeinfo on}

{-$define UseMoreCollisionGroups}

{$define UseTriangleMeshFullPerturbation}

{-$define DebugDraw}

{-$define memdebug}

{$ifdef UseDouble}
 {$define NonSIMD}
{$endif}

{-$define NonSIMD}

{$ifdef NonSIMD}
 {$undef CPU386ASMForSinglePrecision}
 {$undef SIMD}
{$else}
 {$ifdef cpu386}
  {$if not (defined(Darwin) or defined(CompileForWithPIC))}
   {$define CPU386ASMForSinglePrecision}
  {$ifend}
 {$endif}
 {$undef SIMD}
 {$ifdef CPU386ASMForSinglePrecision}
  {$define SIMD}
 {$endif}
{$endif}

interface

uses {$ifdef windows}
      Windows,
      MMSystem,
     {$else}
      {$ifdef unix}
       BaseUnix,
       Unix,
       UnixType,
       {$if defined(linux) or defined(android)}
        linux,
       {$ifend}
      {$else}
       SDL,
      {$endif}
     {$endif}
     {$ifdef DebugDraw}
      {$ifndef NoOpenGL}
       {$ifdef fpc}
        GL,
        GLext,
       {$else}
        OpenGL,
       {$endif}
      {$endif}
     {$endif}
     SysUtils,
     Classes,
     SyncObjs,
{$ifdef KraftPasMP}
     PasMP,
{$endif}
{$ifdef KraftPasJSON}
     PasJSON,
{$endif}
     Math,
     Kraft;

type { TKraftSimpleVehicle }
     TKraftSimpleVehicle=class
      public
       const CountWheels=4; // Count of wheels
       type TDebugDrawLine=procedure(const aP0,aP1:TKraftVector3;const aColor:TKraftVector4) of object;
            { TSpringMath }
            TSpringMath=class
             public
              class function CalculateForce(const aCurrentLength,aRestLength,aStrength:TKraftScalar):TKraftScalar; static;
              class function CalculateForceDamped(const aCurrentLength,aLengthVelocity,aRestLength,aStrength,aDamper:TKraftScalar):TKraftScalar; static;
            end; 
            { TSpringData }
            TSpringData=record
             private
              fCurrentLength:TKraftScalar;
              fCurrentVelocity:TKraftScalar;
            end; 
            PSpringData=^TSpringData;
            { TWheel }
            TWheel=
             (
              FrontLeft=0,
              FrontRight=1,
              BackLeft=2,
              BackRight=3   
             );
            PWheel=^TWheel;
            { TSpringDatas }
            TSpringDatas=array[TWheel] of TSpringData;
            PSpringDatas=^TSpringDatas;
            { TVehicleSettings }
            TVehicleSettings=record
             private
              fWidth:TKraftScalar;
              fHeight:TKraftScalar;
              fLength:TKraftScalar;
              fWheelsPaddingX:TKraftScalar;
              fWheelsPaddingY:TKraftScalar;
              fChassisMass:TKraftScalar;
              fTireMass:TKraftScalar;
              fSpringRestLength:TKraftScalar;
              fSpringStrength:TKraftScalar;
              fSpringDamper:TKraftScalar;
              fAccelerationPower:TKraftScalar;
              fBrakePower:TKraftScalar;
              fMaximumSpeed:TKraftScalar;
              fMaximumReverseSpeed:TKraftScalar;
              fSteeringAngle:TKraftScalar;
              fFrontWheelsGripFactor:TKraftScalar;
              fBackWheelsGripFactor:TKraftScalar;
              fAirResistance:TKraftScalar;
             public
              class function Create:TVehicleSettings; static;
{$ifdef KraftPasJSON}
              procedure LoadFromJSON(const aJSONItem:TPasJSONItem);
              function SaveToJSON:TPasJSONItem;
{$endif}
             public
              property Width:TKraftScalar read fWidth write fWidth;
              property Height:TKraftScalar read fHeight write fHeight;
              property Length:TKraftScalar read fLength write fLength;
              property WheelsPaddingX:TKraftScalar read fWheelsPaddingX write fWheelsPaddingX;
              property WheelsPaddingY:TKraftScalar read fWheelsPaddingY write fWheelsPaddingY;
              property ChassisMass:TKraftScalar read fChassisMass write fChassisMass;
              property TireMass:TKraftScalar read fTireMass write fTireMass;
              property SpringRestLength:TKraftScalar read fSpringRestLength write fSpringRestLength;
              property SpringStrength:TKraftScalar read fSpringStrength write fSpringStrength;
              property SpringDamper:TKraftScalar read fSpringDamper write fSpringDamper;
              property AccelerationPower:TKraftScalar read fAccelerationPower write fAccelerationPower;
              property BrakePower:TKraftScalar read fBrakePower write fBrakePower;
              property MaximumSpeed:TKraftScalar read fMaximumSpeed write fMaximumSpeed;
              property MaximumReverseSpeed:TKraftScalar read fMaximumReverseSpeed write fMaximumReverseSpeed;
              property SteeringAngle:TKraftScalar read fSteeringAngle write fSteeringAngle;
              property FrontWheelsGripFactor:TKraftScalar read fFrontWheelsGripFactor write fFrontWheelsGripFactor;
              property BackWheelsGripFactor:TKraftScalar read fBackWheelsGripFactor write fBackWheelsGripFactor;
              property AirResistance:TKraftScalar read fAirResistance write fAirResistance;
            end;
      private
       fPhysics:TKraft;
       fChassisBody:TKraftRigidBody;
       fChassisShape:TKraftShape;
       fSpringDatas:TSpringDatas;
       fSteeringInput:TKraftScalar;
       fAccelerationInput:TKraftScalar;
       fSettings:TVehicleSettings;
       fForward:TKraftVector3;
       fVelocity:TKraftVector3;       
       fDeltaTime:TKraftScalar;
       fInverseDeltaTime:TKraftScalar;
       fDebugDrawLine:TDebugDrawLine;
       fWorldTransform:TKraftMatrix4x4;
       fWorldLeft:TKraftVector3;
       fWorldRight:TKraftVector3;
       fWorldDown:TKraftVector3;
       fWorldUp:TKraftVector3;
       fWorldBackward:TKraftVector3;
       fWorldForward:TKraftVector3;
       fWorldPosition:TKraftVector3;
       fLastWorldTransform:TKraftMatrix4x4;
       fLastWorldLeft:TKraftVector3;
       fLastWorldRight:TKraftVector3;
       fLastWorldDown:TKraftVector3;
       fLastWorldUp:TKraftVector3;
       fLastWorldBackward:TKraftVector3;
       fLastWorldForward:TKraftVector3;
       fLastWorldPosition:TKraftVector3;
       fVisualWorldTransform:TKraftMatrix4x4;
       fVisualWorldLeft:TKraftVector3;
       fVisualWorldRight:TKraftVector3;
       fVisualWorldDown:TKraftVector3;
       fVisualWorldUp:TKraftVector3;
       fVisualWorldBackward:TKraftVector3;
       fVisualWorldForward:TKraftVector3;
       fVisualWorldPosition:TKraftVector3;
       fInputVertical:TKraftScalar;
       fInputHorizontal:TKraftScalar;
       fInputReset:Boolean;
       fInputBrake:Boolean;
       fInputHandBrake:Boolean;
       fSpeed:TKraftScalar;
       fSpeedKMH:TKraftScalar;
       procedure SetSteeringInput(const aSteeringInput:TKraftScalar);
       procedure SetAccelerationInput(const aAccelerationInput:TKraftScalar);
       function GetSpringRelativePosition(const aWheel:TWheel):TKraftVector3;
       function GetSpringPosition(const aWheel:TWheel):TKraftVector3;
       function GetSpringHitPosition(const aWheel:TWheel):TKraftVector3;
       function GetWheelRollDirection(const aWheel:TWheel):TKraftVector3;
       function GetWheelSlideDirection(const aWheel:TWheel):TKraftVector3;
       function GetWheelTorqueRelativePosition(const aWheel:TWheel):TKraftVector3;
       function GetWheelTorquePosition(const aWheel:TWheel):TKraftVector3;
       function GetWheelGripFactor(const aWheel:TWheel):TKraftScalar;
       function IsGrounded(const aWheel:TWheel):boolean;
       procedure CastSpring(const aWheel:TWheel);
       procedure UpdateWorldTransformVectors;
       procedure UpdateSuspension;
       procedure UpdateSteering;
       procedure UpdateAcceleration;
       procedure UpdateBraking;
       procedure UpdateAirResistance;
      public
       constructor Create(const aPhysics:TKraft); reintroduce;
       destructor Destroy; override;
       procedure Initialize;       
       procedure Update(const aDeltaTime:TKraftScalar);
       procedure StoreWorldTransforms;
       procedure InterpolateWorldTransforms(const aAlpha:TKraftScalar);
{$ifdef DebugDraw}
       procedure DebugDraw;
{$endif}
      public
       property SpringDatas:TSpringDatas read fSpringDatas;
       property Settings:TVehicleSettings read fSettings write fSettings;       
      published
       property Physics:TKraft read fPhysics;
       property ChassisBody:TKraftRigidBody read fChassisBody write fChassisBody;
       property ChassisShape:TKraftShape read fChassisShape write fChassisShape;
       property SteeringInput:TKraftScalar read fSteeringInput write SetSteeringInput;
       property AccelerationInput:TKraftScalar read fAccelerationInput write SetAccelerationInput;
      public
       property WorldTransform:TKraftMatrix4x4 read fWorldTransform write fWorldTransform;
       property WorldLeft:TKraftVector3 read fWorldLeft write fWorldLeft;
       property WorldRight:TKraftVector3 read fWorldRight write fWorldRight;
       property WorldDown:TKraftVector3 read fWorldDown write fWorldDown;
       property WorldUp:TKraftVector3 read fWorldUp write fWorldUp;
       property WorldBackward:TKraftVector3 read fWorldBackward write fWorldBackward;
       property WorldForward:TKraftVector3 read fWorldForward write fWorldForward;
       property WorldPosition:TKraftVector3 read fWorldPosition write fWorldPosition;
       property LastWorldTransform:TKraftMatrix4x4 read fLastWorldTransform write fLastWorldTransform;
       property LastWorldLeft:TKraftVector3 read fLastWorldLeft write fLastWorldLeft;
       property LastWorldRight:TKraftVector3 read fLastWorldRight write fLastWorldRight;
       property LastWorldDown:TKraftVector3 read fLastWorldDown write fLastWorldDown;
       property LastWorldUp:TKraftVector3 read fLastWorldUp write fLastWorldUp;
       property LastWorldBackward:TKraftVector3 read fLastWorldBackward write fLastWorldBackward;
       property LastWorldForward:TKraftVector3 read fLastWorldForward write fLastWorldForward;
       property LastWorldPosition:TKraftVector3 read fLastWorldPosition write fLastWorldPosition;
       property VisualWorldTransform:TKraftMatrix4x4 read fVisualWorldTransform write fVisualWorldTransform;
       property VisualWorldLeft:TKraftVector3 read fVisualWorldLeft write fVisualWorldLeft;
       property VisualWorldRight:TKraftVector3 read fVisualWorldRight write fVisualWorldRight;
       property VisualWorldDown:TKraftVector3 read fVisualWorldDown write fVisualWorldDown;
       property VisualWorldUp:TKraftVector3 read fVisualWorldUp write fVisualWorldUp;
       property VisualWorldBackward:TKraftVector3 read fVisualWorldBackward write fVisualWorldBackward;
       property VisualWorldForward:TKraftVector3 read fVisualWorldForward write fVisualWorldForward;
       property VisualWorldPosition:TKraftVector3 read fVisualWorldPosition write fVisualWorldPosition;
      published
       property InputVertical:TKraftScalar read fInputVertical write fInputVertical;
       property InputHorizontal:TKraftScalar read fInputHorizontal write fInputHorizontal;
       property InputReset:Boolean read fInputReset write fInputReset;
       property InputBrake:Boolean read fInputBrake write fInputBrake;
       property InputHandBrake:Boolean read fInputHandBrake write fInputHandBrake;
       property Speed:TKraftScalar read fSpeed write fSpeed;
       property SpeedKMH:TKraftScalar read fSpeedKMH write fSpeedKMH;
       property DebugDrawLine:TDebugDrawLine read fDebugDrawLine write fDebugDrawLine;
     end;

implementation

{ TKraftSimpleVehicle.TSpringMath }

// Calculates the force which wants to restore the spring to its rest length.
class function TKraftSimpleVehicle.TSpringMath.CalculateForce(const aCurrentLength,aRestLength,aStrength:TKraftScalar):TKraftScalar;
begin
 result:=(aRestLength-aCurrentLength)*aStrength;
end;

// Combines the force which wants to restore the spring to its rest length with the force which wants to damp the spring's motion.
class function TKraftSimpleVehicle.TSpringMath.CalculateForceDamped(const aCurrentLength,aLengthVelocity,aRestLength,aStrength,aDamper:TKraftScalar):TKraftScalar;
begin
 result:=(aRestLength-aCurrentLength)*(aLengthVelocity*aDamper);
end;

{ TKraftSimpleVehicle.TVehicleSettings }

class function TKraftSimpleVehicle.TVehicleSettings.Create:TKraftSimpleVehicle.TVehicleSettings;
begin
 result.fWidth:=1.5;
 result.fHeight:=0.5;
 result.fLength:=3;
 result.fWheelsPaddingX:=0.5;
 result.fWheelsPaddingY:=0.5;
 result.fChassisMass:=100;
 result.fTireMass:=10;
 result.fSpringRestLength:=0.5;
 result.fSpringStrength:=100;
 result.fSpringDamper:=10;
 result.fAccelerationPower:=100;
 result.fBrakePower:=100;
 result.fMaximumSpeed:=10;
 result.fMaximumReverseSpeed:=-5;
 result.fSteeringAngle:=0.5;
 result.fFrontWheelsGripFactor:=1;
 result.fBackWheelsGripFactor:=1;
 result.fAirResistance:=0.1;
end;

{$ifdef KraftPasJSON}
procedure TKraftSimpleVehicle.TVehicleSettings.LoadFromJSON(const aJSONItem:TPasJSONItem);
begin
 if assigned(aJSONItem) and (aJSONItem is TPasJSONItemObject) then begin
  fWidth:=TPasJSON.GetNumber(TPasJSONItemObject(aJSONItem).Properties['width'],fWidth);
  fHeight:=TPasJSON.GetNumber(TPasJSONItemObject(aJSONItem).Properties['height'],fHeight);
  fLength:=TPasJSON.GetNumber(TPasJSONItemObject(aJSONItem).Properties['length'],fLength);
  fWheelsPaddingX:=TPasJSON.GetNumber(TPasJSONItemObject(aJSONItem).Properties['wheelspaddingx'],fWheelsPaddingX);
  fWheelsPaddingY:=TPasJSON.GetNumber(TPasJSONItemObject(aJSONItem).Properties['wheelspaddingy'],fWheelsPaddingY);
  fChassisMass:=TPasJSON.GetNumber(TPasJSONItemObject(aJSONItem).Properties['chassismass'],fChassisMass);
  fTireMass:=TPasJSON.GetNumber(TPasJSONItemObject(aJSONItem).Properties['tiremass'],fTireMass);
  fSpringRestLength:=TPasJSON.GetNumber(TPasJSONItemObject(aJSONItem).Properties['springrestlength'],fSpringRestLength);
  fSpringStrength:=TPasJSON.GetNumber(TPasJSONItemObject(aJSONItem).Properties['springstrength'],fSpringStrength);
  fSpringDamper:=TPasJSON.GetNumber(TPasJSONItemObject(aJSONItem).Properties['springdamper'],fSpringDamper);
  fAccelerationPower:=TPasJSON.GetNumber(TPasJSONItemObject(aJSONItem).Properties['accelerationpower'],fAccelerationPower);
  fBrakePower:=TPasJSON.GetNumber(TPasJSONItemObject(aJSONItem).Properties['brakepower'],fBrakePower);
  fMaximumSpeed:=TPasJSON.GetNumber(TPasJSONItemObject(aJSONItem).Properties['maximumspeed'],fMaximumSpeed);
  fMaximumReverseSpeed:=TPasJSON.GetNumber(TPasJSONItemObject(aJSONItem).Properties['maximumreversespeed'],fMaximumReverseSpeed);
  fSteeringAngle:=TPasJSON.GetNumber(TPasJSONItemObject(aJSONItem).Properties['steeringangle'],fSteeringAngle);
  fFrontWheelsGripFactor:=TPasJSON.GetNumber(TPasJSONItemObject(aJSONItem).Properties['frontwheelsgripfactor'],fFrontWheelsGripFactor);
  fBackWheelsGripFactor:=TPasJSON.GetNumber(TPasJSONItemObject(aJSONItem).Properties['backwheelsgripfactor'],fBackWheelsGripFactor);
  fAirResistance:=TPasJSON.GetNumber(TPasJSONItemObject(aJSONItem).Properties['airresistance'],fAirResistance);
 end;
end;

function TKraftSimpleVehicle.TVehicleSettings.SaveToJSON:TPasJSONItem;
begin
 result:=TPasJSONItemObject.Create;
 TPasJSONItemObject(result).Add('width',TPasJSONItemNumber.Create(fWidth));
 TPasJSONItemObject(result).Add('height',TPasJSONItemNumber.Create(fHeight));
 TPasJSONItemObject(result).Add('length',TPasJSONItemNumber.Create(fLength));
 TPasJSONItemObject(result).Add('wheelspaddingx',TPasJSONItemNumber.Create(fWheelsPaddingX));
 TPasJSONItemObject(result).Add('wheelspaddingy',TPasJSONItemNumber.Create(fWheelsPaddingY));
 TPasJSONItemObject(result).Add('chassismass',TPasJSONItemNumber.Create(fChassisMass));
 TPasJSONItemObject(result).Add('tiremass',TPasJSONItemNumber.Create(fTireMass));
 TPasJSONItemObject(result).Add('springrestlength',TPasJSONItemNumber.Create(fSpringRestLength));
 TPasJSONItemObject(result).Add('springstrength',TPasJSONItemNumber.Create(fSpringStrength));
 TPasJSONItemObject(result).Add('springdamper',TPasJSONItemNumber.Create(fSpringDamper));
 TPasJSONItemObject(result).Add('accelerationpower',TPasJSONItemNumber.Create(fAccelerationPower));
 TPasJSONItemObject(result).Add('brakepower',TPasJSONItemNumber.Create(fBrakePower));
 TPasJSONItemObject(result).Add('maximumspeed',TPasJSONItemNumber.Create(fMaximumSpeed));
 TPasJSONItemObject(result).Add('maximumreversespeed',TPasJSONItemNumber.Create(fMaximumReverseSpeed));
 TPasJSONItemObject(result).Add('steeringangle',TPasJSONItemNumber.Create(fSteeringAngle));
 TPasJSONItemObject(result).Add('frontwheelsgripfactor',TPasJSONItemNumber.Create(fFrontWheelsGripFactor));
 TPasJSONItemObject(result).Add('backwheelsgripfactor',TPasJSONItemNumber.Create(fBackWheelsGripFactor));
 TPasJSONItemObject(result).Add('airresistance',TPasJSONItemNumber.Create(fAirResistance));
end;
{$endif}

{ TKraftSimpleVehicle }

constructor TKraftSimpleVehicle.Create(const aPhysics:TKraft);
begin
 inherited Create;
 fPhysics:=aPhysics;
 fChassisBody:=nil;
 fChassisShape:=nil;
 fSteeringInput:=0;
 fAccelerationInput:=0;
 fForward:=Vector3(0.0,0.0,-1.0);
 fVelocity:=Vector3(0.0,0.0,0.0);
end;

destructor TKraftSimpleVehicle.Destroy;
begin
 inherited Destroy;
end;

procedure TKraftSimpleVehicle.Initialize;
begin
 
 if not (assigned(fChassisBody) and assigned(fChassisShape)) then begin
  
  fChassisBody:=TKraftRigidBody.Create(fPhysics);
  fChassisBody.SetRigidBodyType(krbtDYNAMIC);
  fChassisBody.ForcedMass:=fSettings.ChassisMass+(fSettings.TireMass*CountWheels);

  fChassisShape:=TKraftShapeBox.Create(fPhysics,fChassisBody,Vector3(fSettings.Width*0.5,fSettings.Height*0.5,fSettings.Length*0.5));

  fChassisBody.Finish;

 end;

end;

procedure TKraftSimpleVehicle.SetSteeringInput(const aSteeringInput:TKraftScalar);
begin
 fSteeringInput:=Min(Max(aSteeringInput,-1.0),1.0);
end;

procedure TKraftSimpleVehicle.SetAccelerationInput(const aAccelerationInput:TKraftScalar);
begin
 fAccelerationInput:=Min(Max(aAccelerationInput,-1.0),1.0);
end;

function TKraftSimpleVehicle.GetSpringRelativePosition(const aWheel:TWheel):TKraftVector3;
var BoxSize:TKraftVector3;
    BoxBottom:TKraftScalar;
begin
 BoxSize:=Vector3(fSettings.Width,fSettings.Height,fSettings.Length);
 BoxBottom:=-0.5*BoxSize.y;
 case aWheel of
  TWheel.FrontLeft:begin
   result:=Vector3(BoxSize.x*(fSettings.WheelsPaddingX-0.5),BoxBottom,BoxSize.z*(0.5-fSettings.WheelsPaddingY));
  end;
  TWheel.FrontRight:begin
   result:=Vector3(BoxSize.x*(0.5-fSettings.WheelsPaddingX),BoxBottom,BoxSize.z*(0.5-fSettings.WheelsPaddingY));
  end;
  TWheel.BackLeft:begin
   result:=Vector3(BoxSize.x*(fSettings.WheelsPaddingX-0.5),BoxBottom,BoxSize.z*(fSettings.WheelsPaddingY-0.5));
  end;
  TWheel.BackRight:begin
   result:=Vector3(BoxSize.x*(0.5-fSettings.WheelsPaddingX),BoxBottom,BoxSize.z*(fSettings.WheelsPaddingY-0.5));
  end;
  else begin
   result:=Vector3(0.0,0.0,0.0);
  end;
 end; 
end;

function TKraftSimpleVehicle.GetSpringPosition(const aWheel:TWheel):TKraftVector3;
begin
 result:=Vector3TermMatrixMul(GetSpringRelativePosition(aWheel),fWorldTransform);
end;

function TKraftSimpleVehicle.GetSpringHitPosition(const aWheel:TWheel):TKraftVector3;
begin
 result:=Vector3Add(GetSpringPosition(aWheel),Vector3ScalarMul(fWorldDown,fSpringDatas[aWheel].fCurrentLength));
end;

function TKraftSimpleVehicle.GetWheelRollDirection(const aWheel:TWheel):TKraftVector3;
begin
 if aWheel in [TWheel.FrontLeft,TWheel.FrontRight] then begin
  result:=Vector3TermQuaternionRotate(fWorldForward,QuaternionFromAxisAngle(Vector3(0.0,1.0,0.0),fSteeringInput*fSettings.SteeringAngle));
 end else begin
  result:=fWorldForward;
 end;
end;

function TKraftSimpleVehicle.GetWheelSlideDirection(const aWheel:TWheel):TKraftVector3;
begin
 result:=Vector3Cross(fWorldUp,GetWheelRollDirection(aWheel));
end;

function TKraftSimpleVehicle.GetWheelTorqueRelativePosition(const aWheel:TWheel):TKraftVector3;
var BoxSize:TKraftVector3;
begin
 BoxSize:=Vector3(fSettings.Width,fSettings.Height,fSettings.Length);
 case aWheel of
  TWheel.FrontLeft:begin
   result:=Vector3(BoxSize.x*(fSettings.WheelsPaddingX-0.5),0.0,BoxSize.z*(0.5-fSettings.WheelsPaddingY));
  end;
  TWheel.FrontRight:begin
   result:=Vector3(BoxSize.x*(0.5-fSettings.WheelsPaddingX),0.0,BoxSize.z*(0.5-fSettings.WheelsPaddingY));
  end;
  TWheel.BackLeft:begin
   result:=Vector3(BoxSize.x*(fSettings.WheelsPaddingX-0.5),0.0,BoxSize.z*(fSettings.WheelsPaddingY-0.5));
  end;
  TWheel.BackRight:begin
   result:=Vector3(BoxSize.x*(0.5-fSettings.WheelsPaddingX),0.0,BoxSize.z*(fSettings.WheelsPaddingY-0.5));
  end;
  else begin
   result:=Vector3(0.0,0.0,0.0);
  end;
 end;
end;

function TKraftSimpleVehicle.GetWheelTorquePosition(const aWheel:TWheel):TKraftVector3;
begin
 result:=Vector3TermMatrixMul(GetWheelTorqueRelativePosition(aWheel),fWorldTransform);
end;

function TKraftSimpleVehicle.GetWheelGripFactor(const aWheel:TWheel):TKraftScalar;
begin
 if aWheel in [TWheel.FrontLeft,TWheel.FrontRight] then begin
  result:=fSettings.FrontWheelsGripFactor;
 end else begin
  result:=fSettings.BackWheelsGripFactor;
 end;
end;

function TKraftSimpleVehicle.IsGrounded(const aWheel:TWheel):boolean;
begin
 result:=fSpringDatas[aWheel].fCurrentLength<fSettings.SpringRestLength;
end;

procedure TKraftSimpleVehicle.CastSpring(const aWheel:TWheel);
var RayOrigin,RayDirection,HitPoint,HitNormal:TKraftVector3;
    RayLength,PreviousLength,CurrentLength,HitTime:TKraftScalar;
    HitShape:TKraftShape;
begin
 RayOrigin:=GetSpringPosition(aWheel);
 PreviousLength:=fSpringDatas[aWheel].fCurrentLength;
 RayDirection:=fWorldDown;
 RayLength:=fSettings.SpringRestLength;
 if fPhysics.RayCast(RayOrigin,RayDirection,RayLength,HitShape,HitTime,HitPoint,HitNormal,[0],nil) then begin
  CurrentLength:=HitTime;
 end else begin
  CurrentLength:=fSettings.SpringRestLength;
 end;
 fSpringDatas[aWheel].fCurrentVelocity:=(CurrentLength-PreviousLength)*fInverseDeltaTime;
 fSpringDatas[aWheel].fCurrentLength:=CurrentLength;
end;

procedure TKraftSimpleVehicle.UpdateWorldTransformVectors;
begin
 fWorldTransform:=fChassisBody.WorldTransform;
 fWorldRight:=Vector3(PKraftRawVector3(pointer(@fWorldTransform[0,0]))^);
 fWorldLeft:=Vector3Neg(fWorldRight);
 fWorldUp:=Vector3(PKraftRawVector3(pointer(@fWorldTransform[1,0]))^);
 fWorldDown:=Vector3Neg(fWorldUp);
 fWorldForward:=Vector3(PKraftRawVector3(pointer(@fWorldTransform[2,0]))^);
 fWorldBackward:=Vector3Neg(fWorldForward);
 fWorldPosition:=Vector3(PKraftRawVector3(pointer(@fWorldTransform[3,0]))^);
end;

procedure TKraftSimpleVehicle.UpdateSuspension;
var Wheel:TWheel;
    CurrentLength,CurrentVelocity,Force:TKraftScalar;
begin
 for Wheel:=Low(TWheel) to High(TWheel) do begin
  CastSpring(Wheel);
  CurrentLength:=fSpringDatas[Wheel].fCurrentLength;
  CurrentVelocity:=fSpringDatas[Wheel].fCurrentVelocity;
  Force:=TSpringMath.CalculateForceDamped(CurrentLength,CurrentVelocity,fSettings.SpringRestLength,fSettings.SpringStrength,fSettings.SpringDamper);
  if abs(Force)>EPSILON then begin
   fChassisBody.AddForceAtPosition(Vector3ScalarMul(fWorldUp,Force),GetSpringPosition(Wheel),kfmForce,true);
  end; 
 end;
end;

procedure TKraftSimpleVehicle.UpdateSteering;
var Wheel:TWheel;
    SpringPosition,SlideDirection,Force:TKraftVector3;
    SlideVelocity,DesiredVelocityChange,DesiredAcceleration:TKraftScalar;
begin
 for Wheel:=Low(TWheel) to High(TWheel) do begin
  if IsGrounded(Wheel) then begin
   SpringPosition:=GetSpringPosition(Wheel);
   SlideDirection:=GetWheelSlideDirection(Wheel);
   SlideVelocity:=Vector3Dot(SlideDirection,fChassisBody.GetWorldLinearVelocityFromPoint(SpringPosition));
   DesiredVelocityChange:=-SlideVelocity*GetWheelGripFactor(Wheel);
   DesiredAcceleration:=DesiredVelocityChange*fInverseDeltaTime;
   Force:=Vector3ScalarMul(SlideDirection,DesiredAcceleration*fSettings.TireMass);
   if Vector3Length(Force)>EPSILON then begin
    fChassisBody.AddForceAtPosition(Force,GetWheelTorquePosition(Wheel),kfmForce,true);
   end; 
  end; 
 end;
end; 

procedure TKraftSimpleVehicle.UpdateAcceleration;
var Wheel:TWheel;
    ForwardSpeed,Speed:TKraftScalar;
    MovingForward:boolean;
    Position,WheelForward,Force:TKraftVector3;
begin
 if not IsZero(fAccelerationInput) then begin
  ForwardSpeed:=Vector3Dot(fWorldForward,fChassisBody.LinearVelocity);
  MovingForward:=ForwardSpeed>0.0;
  Speed:=abs(ForwardSpeed);
  for Wheel:=Low(TWheel) to High(TWheel) do begin
   if IsGrounded(Wheel) and
      ((MovingForward and (Speed<fSettings.fMaximumSpeed)) or 
       ((not MovingForward) and (Speed<fSettings.fMaximumReverseSpeed))) then begin
    Position:=GetWheelTorquePosition(Wheel);
    WheelForward:=GetWheelRollDirection(Wheel);
    Force:=Vector3ScalarMul(WheelForward,fAccelerationInput*fSettings.AccelerationPower);
    if Vector3Length(Force)>EPSILON then begin
     fChassisBody.AddForceAtPosition(Force,Position,kfmForce,true);
    end;
   end; 
  end;
 end; 
end; 

procedure TKraftSimpleVehicle.UpdateBraking;
const AlmostStoppedSpeed=2.0;
var Wheel:TWheel;
    ForwardSpeed,Speed,BrakeRatio,RollVelocity,DesiredVelocityChange,DesiredAcceleration:TKraftScalar;
    AlmostStopping,AccelerationContrary:boolean;
    SpringPosition,RollDirection,Force:TKraftVector3;
begin
 ForwardSpeed:=Vector3Dot(fWorldForward,fChassisBody.LinearVelocity);
 Speed:=abs(ForwardSpeed);
 AlmostStopping:=Speed<AlmostStoppedSpeed;
 if AlmostStopping then begin
  BrakeRatio:=1.0;
 end else begin
  AccelerationContrary:=IsZero(fAccelerationInput) and (Vector3Dot(Vector3ScalarMul(fWorldForward,fAccelerationInput),fChassisBody.LinearVelocity)<0.0);
  if AccelerationContrary then begin
   BrakeRatio:=1.0;
  end else if IsZero(fAccelerationInput) then begin
   BrakeRatio:=0.1;
  end else begin
   exit;
  end;
 end;
 
 for Wheel:=Low(TWheel) to High(TWheel) do begin
  if IsGrounded(Wheel) then begin
   SpringPosition:=GetSpringPosition(Wheel);
   RollDirection:=GetWheelRollDirection(Wheel);
   RollVelocity:=Vector3Dot(RollDirection,fChassisBody.GetWorldLinearVelocityFromPoint(SpringPosition));
   DesiredVelocityChange:=-RollVelocity*BrakeRatio*fSettings.BrakePower;
   DesiredAcceleration:=DesiredVelocityChange*fInverseDeltaTime;
   Force:=Vector3ScalarMul(RollDirection,DesiredAcceleration*fSettings.TireMass);
   if Vector3Length(Force)>EPSILON then begin
    fChassisBody.AddForceAtPosition(Force,GetWheelTorquePosition(Wheel),kfmForce,true);
   end;
  end; 
 end;

end;

procedure TKraftSimpleVehicle.UpdateAirResistance;
var Force:TKraftVector3;
begin
 Force:=Vector3ScalarMul(fVelocity,-fSettings.AirResistance*Vector3Length(Vector3(fSettings.Width,fSettings.Height,fSettings.Length)));
 if Vector3Length(Force)>EPSILON then begin
  fChassisBody.AddWorldForce(Force,kfmForce,true);
 end;
end;

procedure TKraftSimpleVehicle.Update(const aDeltaTime:TKraftScalar);
begin
 fDeltaTime:=aDeltaTime;
 fInverseDeltaTime:=1.0/fDeltaTime;
 UpdateWorldTransformVectors;
 UpdateSuspension;
 UpdateSteering;
 UpdateAcceleration;
 UpdateBraking;
 UpdateAirResistance;
end;

procedure TKraftSimpleVehicle.StoreWorldTransforms;
begin
 UpdateWorldTransformVectors;
 fLastWorldTransform:=fWorldTransform;
 fLastWorldRight:=Vector3(PKraftRawVector3(pointer(@fLastWorldTransform[0,0]))^);
 fLastWorldLeft:=Vector3Neg(fLastWorldRight);
 fLastWorldUp:=Vector3(PKraftRawVector3(pointer(@fLastWorldTransform[1,0]))^);
 fLastWorldDown:=Vector3Neg(fLastWorldUp);
 fLastWorldForward:=Vector3(PKraftRawVector3(pointer(@fLastWorldTransform[2,0]))^);
 fLastWorldBackward:=Vector3Neg(fLastWorldForward);
 fLastWorldPosition:=Vector3(PKraftRawVector3(pointer(@fLastWorldTransform[3,0]))^);
end;

procedure TKraftSimpleVehicle.InterpolateWorldTransforms(const aAlpha:TKraftScalar);
begin
 UpdateWorldTransformVectors;
 fVisualWorldTransform:=Matrix4x4Slerp(fLastWorldTransform,fWorldTransform,aAlpha);
 fVisualWorldRight:=Vector3(PKraftRawVector3(pointer(@fVisualWorldTransform[0,0]))^);
 fVisualWorldLeft:=Vector3Neg(fVisualWorldRight);
 fVisualWorldUp:=Vector3(PKraftRawVector3(pointer(@fVisualWorldTransform[1,0]))^);
 fVisualWorldDown:=Vector3Neg(fVisualWorldUp);
 fVisualWorldForward:=Vector3(PKraftRawVector3(pointer(@fVisualWorldTransform[2,0]))^);
 fVisualWorldBackward:=Vector3Neg(fVisualWorldForward);
 fVisualWorldPosition:=Vector3(PKraftRawVector3(pointer(@fVisualWorldTransform[3,0]))^);
end;

{$ifdef DebugDraw}
procedure TKraftSimpleVehicle.DebugDraw;
begin

end;
{$endif}

end.

