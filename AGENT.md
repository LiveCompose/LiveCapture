---
mode: agent
---
1.每次生成完代码请使用如下命令进行构建验证：“xcodebuild -project LiveCapture.xcodeproj -scheme LiveCapture -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | grep -A 5 "error:"”
2.除非额外说明，否则不需要在结束生成任何的文档