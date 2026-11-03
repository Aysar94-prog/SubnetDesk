using System;
using System.Drawing;
using System.IO;
using System.Windows.Forms;
using SubnetDesk.Deployment;
internal static class AgentTests {
    [STAThread] static int Main(string[] args) {
        if (args.Length > 0 && args[0] == "--network") { NetworkIdentityTests.Run(); return 0; }
        SelfTest.Run();
        InventoryContractTests.Run();
        AgentUpdateTests.Run();
        HelperSecurityTests.Run();
        MachineReceiverPolicyTests.Run();
        PackageRemovalTests.Run();
        SilentAgentSetupTests.Run();
        AgentRolloutTests.Run();
        if (args.Length > 0) {
            Application.EnableVisualStyles();
            using (var form = new AgentSettings()) {
                form.StartPosition = FormStartPosition.Manual; form.Location = new Point(-10000, -10000); form.ShowInTaskbar = false;
                form.Show(); Application.DoEvents(); form.PerformLayout();
                using (var image = new Bitmap(form.Width, form.Height)) { form.DrawToBitmap(image, new Rectangle(0, 0, form.Width, form.Height)); image.Save(args[0]); }
            }
        }
        return 0;
    }
}
