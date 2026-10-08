#include "flutter_window.h"

#include <desktop_multi_window/desktop_multi_window_plugin.h>
#include <texture_rgba_renderer/texture_rgba_renderer_plugin_c_api.h>
#include <flutter_gpu_texture_renderer/flutter_gpu_texture_renderer_plugin_c_api.h>

#include "flutter/generated_plugin_registrant.h"

#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <windows.h>

#include <optional>
#include <memory>
#include <algorithm>

#include "win32_desktop.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  attention_channel_ = std::make_unique<flutter::MethodChannel<>>(
      flutter_controller_->engine()->messenger(), "subnetdesk/window",
      &flutter::StandardMethodCodec::GetInstance());
  attention_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<>& call,
             std::unique_ptr<flutter::MethodResult<>> result) {
        if (call.method_name() != "showAttentionDock") {
          result->NotImplemented();
          return;
        }
        const HWND window = GetHandle();
        MONITORINFO monitor = {};
        monitor.cbSize = sizeof(monitor);
        if (!GetMonitorInfo(MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST), &monitor)) {
          result->Error("monitor", "Cannot locate the attention dock work area");
          return;
        }
        const UINT dpi = GetDpiForWindow(window);
        const int width = (std::min)(MulDiv(360, dpi ? dpi : 96, 96),
                                    static_cast<int>(monitor.rcWork.right - monitor.rcWork.left));
        const int height = (std::min)(MulDiv(600, dpi ? dpi : 96, 96),
                                     static_cast<int>(monitor.rcWork.bottom - monitor.rcWork.top));
        // Never call SetForegroundWindow or an activating restore for a buzzer.
        ShowWindow(window, SW_SHOWNOACTIVATE);
        if (!SetWindowPos(window, HWND_TOPMOST, monitor.rcWork.right - width,
                          monitor.rcWork.bottom - height, width, height,
                          SWP_NOACTIVATE | SWP_SHOWWINDOW)) {
          result->Error("window", "Cannot show the attention dock");
          return;
        }
        result->Success();
      });

  flutter::MethodChannel<> channel(
    flutter_controller_->engine()->messenger(),
    "org.rustdesk.rustdesk/host",
    &flutter::StandardMethodCodec::GetInstance());

  channel.SetMethodCallHandler(
    [](const flutter::MethodCall<>& call, std::unique_ptr<flutter::MethodResult<>> result) {
      if (call.method_name() == "bumpMouse") {
        auto arguments = call.arguments();

        int dx = 0, dy = 0;

        if (std::holds_alternative<flutter::EncodableMap>(*arguments)) {
          auto argsMap = std::get<flutter::EncodableMap>(*arguments);

          auto dxIt = argsMap.find(flutter::EncodableValue("dx"));
          auto dyIt = argsMap.find(flutter::EncodableValue("dy"));

          if ((dxIt != argsMap.end()) && std::holds_alternative<int>(dxIt->second)) {
            dx = std::get<int>(dxIt->second);
          }
          if ((dyIt != argsMap.end()) && std::holds_alternative<int>(dyIt->second)) {
            dy = std::get<int>(dyIt->second);
          }
        } else if (std::holds_alternative<flutter::EncodableList>(*arguments)) {
          auto argsList = std::get<flutter::EncodableList>(*arguments);

          if ((argsList.size() >= 1) && std::holds_alternative<int>(argsList[0])) {
            dx = std::get<int>(argsList[0]);
          }
          if ((argsList.size() >= 2) && std::holds_alternative<int>(argsList[1])) {
            dy = std::get<int>(argsList[1]);
          }
        }

        bool succeeded = Win32Desktop::BumpMouse(dx, dy);

        result->Success(succeeded);
      }
    });

  DesktopMultiWindowSetWindowCreatedCallback([](void *controller) {
    auto *flutter_view_controller =
        reinterpret_cast<flutter::FlutterViewController *>(controller);
    auto *registry = flutter_view_controller->engine();
    TextureRgbaRendererPluginCApiRegisterWithRegistrar(
        registry->GetRegistrarForPlugin("TextureRgbaRendererPlugin"));
    FlutterGpuTextureRendererPluginCApiRegisterWithRegistrar(
        registry->GetRegistrarForPlugin("FlutterGpuTextureRendererPluginCApi"));
  });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  return true;
}

void FlutterWindow::OnDestroy() {
  attention_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
