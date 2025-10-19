---
mode: agent
---
1.每次生成完代码请使用如下命令进行构建验证：“xcodebuild -project LiveCapture.xcodeproj -scheme LiveCapture -destination 'platform=iOS Simulator,name=iPhone 16 Pro' clean build 2>&1 | tail -50 ”