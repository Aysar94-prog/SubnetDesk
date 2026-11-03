using System;
using System.ServiceProcess;

namespace SubnetDesk.Deployment {
    internal static class HelperActions {
        internal static bool Allowed(string action) { return action == "install" || action == "uninstall" || action == "repair" || action == "start" || action == "stop" || action == "restart"; }
        internal static string Execute(string action) {
            if (!Allowed(action) || action == "install") throw new InvalidOperationException("Unsupported Helper action.");
            var inventory = Msi.Inventory(); string product = Data.Text(inventory, "productCode");
            if (action == "uninstall" || action == "repair") {
                if (product == "") { if (action == "uninstall") return "Helper is already uninstalled."; throw new InvalidOperationException("Helper is not installed."); }
                Msi.MsiSetInternalUI(2, IntPtr.Zero);
                uint code = Msi.MsiConfigureProductEx(product, 0, action == "uninstall" ? 2 : 5, action == "repair" ? "REINSTALL=ALL REINSTALLMODE=omus REBOOT=ReallySuppress LAUNCH_TRAY_APP=N" : "REBOOT=ReallySuppress");
                if (code != 0 && code != 3010 && code != 1641) throw new InvalidOperationException("Windows Installer code " + code + ".");
                if (action == "uninstall") {
                    if (Data.Text(Msi.Inventory(), "productCode") != "") throw new InvalidOperationException("Helper removal could not be verified.");
                    return "Helper uninstalled. Agent remains available.";
                }
            }
            using (var service = new ServiceController("SubnetDesk")) {
                if ((action == "stop" || action == "restart") && service.Status != ServiceControllerStatus.Stopped) {
                    service.Stop(); service.WaitForStatus(ServiceControllerStatus.Stopped, TimeSpan.FromSeconds(30));
                }
                if (action != "stop") {
                    service.Refresh(); if (service.Status == ServiceControllerStatus.Stopped) service.Start();
                    service.WaitForStatus(ServiceControllerStatus.Running, TimeSpan.FromSeconds(30));
                }
            }
            return "Helper " + action + " completed and service state verified.";
        }
    }
}
