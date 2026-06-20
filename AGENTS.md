# FilmCam Assist — 合作备忘

## 工作流
- 每次改完代码后，直接执行 `flutter build apk --debug` + `adb install -r` 编译安装到设备，不用等用户提醒。
- 纯UI改动可以先 `flutter run` 用 hot reload 快速迭代，确认没问题再编译安装。
