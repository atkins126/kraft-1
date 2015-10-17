unit UnitDemoScene;
{$j+}

interface

uses SysUtils,Classes,Windows,OpenGL,kraft;

type TDemoScene=class;

     TDemoSceneClass=class of TDemoScene;

     TDemoScene=class
      public
       fKraftPhysics:TKraft;
       GarbageCollector:TList;
       constructor Create; virtual;
       destructor Destroy; override;
       procedure Step(const DeltaTime:double); virtual;
       property KraftPhysics:TKraft read fKraftPhysics;
     end;

implementation

uses UnitFormMain,UnitFormGL;

constructor TDemoScene.Create;
begin
 inherited Create;
 fKraftPhysics:=TKraft.Create(1);
 GarbageCollector:=TList.Create;
end;

destructor TDemoScene.Destroy;
var Index:longint;
    ConvexHull,NextConvexHull:TKraftConvexHull;
begin
 wglMakeCurrent(FormGL.hDCGL,FormGL.hGL);
 for Index:=0 to GarbageCollector.Count-1 do begin
  TObject(GarbageCollector[Index]).Free;
 end;
 GarbageCollector.Free;
 while assigned(fKraftPhysics.RigidBodyFirst) do begin
  fKraftPhysics.RigidBodyFirst.Free;
 end;
 while assigned(fKraftPhysics.MeshFirst) do begin
  fKraftPhysics.MeshFirst.Free;
 end;
 while assigned(fKraftPhysics.ConstraintFirst) do begin
  fKraftPhysics.ConstraintFirst.Free;
 end;
 ConvexHull:=fKraftPhysics.ConvexHullFirst;
 wglMakeCurrent(0,0);
 FreeAndNil(fKraftPhysics);
 inherited Destroy;
end;

procedure TDemoScene.Step(const DeltaTime:double);
begin
end;

end.