class DemoXRay extends UMenuModMenuItem config(User);

var DemoXRayMut Mut;

function Execute() {
    Mut = MenuItem.Owner.Root.Console.ViewPort.Actor.Spawn(class'DemoXRayMut');
    Mut.RegisterHUDMutator();
}

defaultproperties
{
      MenuCaption="Demo&XRay"
      MenuHelp=""
      MenuItem=None
}
