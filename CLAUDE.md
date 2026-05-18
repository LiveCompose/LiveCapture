1.每次生成完代码请使用如下命令进行构建验证：“xcodebuild -project LiveCapture.xcodeproj -scheme LiveCapture -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -A 5 "error:"”
2.除非额外说明，否则不需要在结束生成任何的文档，总结信息要简要
3.代码文件的架构与基本内容请从文件开头的注释获取（若信息不足再读取源文件），并在结束时更新对应的函数简介