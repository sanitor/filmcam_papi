# FilmCam Papi — 合作备忘

## 工作流
- 每次改完代码后，直接执行 `flutter build apk --debug` + `adb install -r` 编译安装到设备，不用等用户提醒。
- 纯UI改动可以先 `flutter run` 用 hot reload 快速迭代，确认没问题再编译安装。
- **master 已开启 branch protection**，要求 `analyze` + `build` CI check 通过才能合并。务必走分支 + PR 流程：
  ```bash
  git checkout -b feat/xxx              # 开功能分支
  git push origin feat/xxx              # 触发 CI
  # 等 CI 通过后：
  gh pr create --fill                   # 提 PR
  gh pr merge --squash --delete-branch  # 合并并删除分支
  ```

## CI & Release
- push 到 `master` 或 PR 会自动触发 GitHub Actions：`flutter analyze` + `flutter build apk --debug`，APK 上传到 artifact。
- 发版流程：
  ```bash
  git commit -m "xxx"
  git tag v<版本号>        # 如 v1.1.0
  git push --tags
  ```
  推送 tag 后 CI 自动构建 release APK 并创建 GitHub Release。
- 版本号使用 semver：`major.minor.patch`，`pubspec.yaml` 里的 `version` 字段保持与最新 tag 一致。
