# iOSAutoTimingArchiveTask


### 前言

作为一个移动端程序员，每次 feature add 或者 bug fix 后经常要打包交付给 QA，以前传统的操作都是手动点击 `Xcode -> Product -> Archive -> Organizer -> Distrubute App -> ipa 上传到第三方内测分发平台（蒲公英、fir）-> 手动填写更新日志 -> 发送安装链接到部门群（钉钉或者企业微信）`，看起来好像很机械和繁琐，又没啥技术含量是吧......

如果能把这部分工作给自动化了就好了，每天可以省一点时间出来发呆也挺好的。需求整理一下大概是这样：

1. 能够定时触发；
2. 自动打包；
3. 自动读取某个时间段内的 git commit messge 信息当做更新日志；
4. 打包完成自动发送安装链接到部门群（钉钉或者企业微信）；



### 实现

#### 需求一、定时任务

调研了一下，Mac OS 可以基于 launchctl 来配置定时任务。可以配置到不同级别的 **LaunchAgents** 下，几种的区别如下：

```shell
~/Library/LaunchAgents 由用户自己定义的任务项
/Library/LaunchAgents 由管理员为用户定义的任务项
/Library/LaunchDaemons 由管理员定义的守护进程任务项
/System/Library/LaunchAgents 由Mac OS X为用户定义的任务项
/System/Library/LaunchDaemons 由Mac OS X定义的守护进程任务项
```



我们配置在用户目录下就行，也就是这个目录 ~/Library/LaunchAgents，按照固定的格式新建一个 Plist 文件就行，可以看到已经有一些第三方的任务在这里了:

![image-20200126210005856](http://liangjinggege.com/2020-01-26-133204.png)



我的配置文件是这样：

```xml
<plist version="1.0">
<dict>
  <!-- Label唯一的标识 -->
  <key>Label</key>
  <string>com.autoArchiveTask.plist</string>

  <key>Program</key>
  <string>/Users/username/Desktop/code/Project/run.sh</string>

  <!-- 指定要运行的脚本 -->
  <key>ProgramArguments</key>
  <array>
    <string>/Users/username/Desktop/code/Project/run.sh</string>
  </array>
  <!-- 指定要运行的时间 -->
  <key>StartCalendarInterval</key>
  <array>
    <dict>
        <key>Minute</key>
        <integer>00</integer>
        <key>Hour</key>
        <integer>11</integer>
    </dict>
    <dict>
        <key>Minute</key>
        <integer>00</integer>
        <key>Hour</key>
        <integer>16</integer>
    </dict>
  </array>

<!-- 标准输出文件 -->
<key>StandardOutPath</key>
<string>/Users/username/Desktop/code/Project/run.log</string>
<!-- 标准错误输出文件，错误日志 -->
<key>StandardErrorPath</key>
<string>/Users/username/Desktop/code/Project/run.error</string>
</dict>
</plist>
```



相关字段的解释如下：

1. Label：对应的需要保证全局唯一性；
2. Program：要运行脚本；
3. ProgramArguments：指定要运行的脚本；
4. StartCalendarInterval：运行的时间，单个时间点使用 dict，多个时间点使用 array <dict>
5. StartInterval：时间间隔，与 StartCalendarInterval 使用其一，单位为秒
6. StandardInPath、StandardOutPath、StandardErrorPath：标准的输入、输出、错误文件



配置好了就可以加载了，加载后就生效了，相关的命令如下：

```shell
# 加载任务, -w选项会将 plist 文件中无效的 key 覆盖掉，建议加上
launchctl load -w xxx.plist

# 删除任务
launchctl unload -w xxx.plist

# 查看任务列表, 使用 grep '任务部分名字' 过滤
launchctl list | grep 'xxx'

# 立即执行一次任务，可用来测试
launchctl start xxx.plist
```



#### 需求二、自动打包

这个使用 fastlane 就行，很好很强大。相关的配置可参见[官网](https://github.com/fastlane/fastlane)，建议使用 brew 方式安装。配置安装文档就行，

由于我这个是多 target 工程，所以我这边的可能多一点配置，我的 Fastfile 文件配置如下：

```shell
default_platform(:ios)

# 网络请求依赖
require 'net/http'
require 'uri'
require 'json'


 platform :ios do
		
   desc "发布app到 App Store 或者 Fir.im "
   lane :customer_hoc do
     # add actions here: https://docs.fastlane.tools/actions
     sh "fastlane adhoc --env Customer"
   end

   desc "发布app到 App Store 或者 Fir.im "
   lane :driver_hoc do
     # add actions here: https://docs.fastlane.tools/actions
     sh "fastlane adhoc --env Driver"
   end
		 


   desc "发布指定Target到 Fir.im"
   lane :adhoc do
   gym(
     clean:true, #打包前clean项目
     workspace: "Hedgehog.xcworkspace",
     export_method: "ad-hoc", #导出方式
     scheme: ENV['SCHEME_NAME'], #scheme
     output_name: ENV['SCHEME_NAME']+".ipa", # ipa 文件名
     output_directory: "./ipa", #ipa的存放目录
     export_options: {
         provisioningProfiles: {
             "cn.ccmore.hedgehog.customer"=>"CustomerAdhoc", 
             "cn.ccmore.hedgehog.driver"=>"DricerAdhoc"
         }
     }
   )
   # 前往fir.im获取 api token, 将鼠标放置右上角账号上面, 在下拉窗选择API token
   # 若使用的蒲公英, 请前往 https://www.pgyer.com/ 查看上传方法
   # 如果使用Firimfile, 此处为 firim 即可
   firim(firim_api_token:'xxxx')

  
  # 钉钉机器人
  app_patch   = "ipa/" + ENV['SCHEME_NAME']+".ipa"
  app_version = get_ipa_info_plist_value(ipa: app_patch, key: "CFBundleShortVersionString")
  app_build_version = get_ipa_info_plist_value(ipa: app_patch, key: "CFBundleVersion")
  app_name    = get_ipa_info_plist_value(ipa: app_patch, key: "CFBundleDisplayName")


  # 根据 SCHEME_NAME 区分下载链接
  app_url = "https://fir.im/6udv"

  if ENV['SCHEME_NAME'] == "Driver" then
    app_url = "https://fir.im/sa4q"
  end
  
  app_icon = "./Hedgehog/ipa/icons/57.png"
  dingTalk_url = "https://oapi.dingtalk.com/robot/send?access_token=xxx"
  
  markdown = 
  {
    msgtype: "link", 
    link: {
        text: "iOS #{ENV['SCHEME_NAME']} 更新了！！！", 
        title: "iOS #{ENV['SCHEME_NAME']} #{app_version} (#{app_build_version}) 内测版", 
        picUrl: "#{app_icon}", 
        messageUrl: "#{app_url}"
    }
 }

  uri = URI.parse(dingTalk_url)
  https = Net::HTTP.new(uri.host, uri.port)
  https.use_ssl = true

  request = Net::HTTP::Post.new(uri.request_uri)
  request.add_field('Content-Type', 'application/json')
  request.body = markdown.to_json

  response = https.request(request)
  puts "------------------------------"
  puts "Response #{response.code} #{response.message}: #{response.body}"
  end

 end
```



上传到第三方内测平台（蒲公英、fir等）Fastlane 也有相关的插件，一行代码搞定，如 Fir 就是：

```shell
# 前往fir.im获取 api token, 将鼠标放置右上角账号上面, 在下拉窗选择API token
# 若使用的蒲公英, 请前往 https://www.pgyer.com/ 查看上传方法
# 如果使用Firimfile, 此处为 firim 即可
firim(firim_api_token:'xxxx') 
```



#### 需求三、读取 git commit messge

TODO: 等待实现。



#### 需求四、自动发送安装消息

我这边目前使用的钉钉进行协作，可以在相关工作群使用钉钉机器人自动发送消息。找钉钉群管理员添加一下获取  token 就行。可以向这个地址 `https://oapi.dingtalk.com/robot/send?access_token=Your Token` 发送纯文本、图文、markdown 等格式的消息，还可以填写需要 @ 的测试妹子们。

<img src="http://liangjinggege.com/2020-01-26-132340.png" alt="image-20200126212339968" style="zoom:50%;" />





其他企业微信好像也是可以的，可以自行去查看文档。



### 踩坑

#### 一、定时脚本执行 /bin/sh:  xxx/run.sh: Operation not permitted

##### 原因：

<img src="http://liangjinggege.com/2020-01-26-121353.png" alt="image-20200126201353427" style="zoom:50%;" />

首先我配置的定时脚本路径在 /Users/username/Desktop/code/Project/run.sh，没有和定时任务的 Plist 配置文件在一个目录下，而配置的定时脚本声明的是 **#!/bin/sh**，意思是使用 **/bin/sh** 来解释执行，但是却没有给完全磁盘访问的权限。

##### 解决方案：

给足访问权限就行。系统偏好设置 -> 安全性与隐私-> 完全磁盘访问权限，查看是否有勾选☑️ 在定时脚本中声明的解释执行的 shell 的路径，就是**#!/bin/** 后面接的，有 bash 、sh、 zsh 等，我的是 sh。没有的话就添加进去。

<img src="/Users/chenliangjing/Library/Application Support/typora-user-images/image-20200126204424708.png" alt="image-20200126204424708" style="zoom:50%;" />

#### 二、在定时脚本中直接执行 fastlane 打包命令出错： /Users/username/Desktop/code/Project/run.sh ： fastlane: command not found

##### 原因：

虽然 cd 到了当前项目目录，但还是报 fastlane 找不到

##### 解决方案：

使用全路径 fastlane 执行命令

```shell
/Users/username/.fastlane/bin/fastlane lane
```



### 总结

总共折腾了一两天时间，流程基本都跑通了，还剩抓取指定时间段内的 git commit message 当做更新日志的 TODO，总体上还是很愉悦和有成就感的，以后就可以专心干其他的事情了，打包几乎无感，也不用怕忘记。nice！

效果如下：

<img src="http://liangjinggege.com/2020-01-26-125435.png" alt="image-20200126205435079" style="zoom:50%;" />



### 参考链接

1. [Mac上，执行定时任务：launchctl](https://my.oschina.net/shede333/blog/470377)
2. [Operation not permitted](http://osxdaily.com/2018/10/09/fix-operation-not-permitted-terminal-error-macos/)

3. [Fastlane](https://docs.fastlane.tools/)
4. [钉钉开发文档](https://ding-doc.dingtalk.com/doc#/serverapi2/qf2nxq)



---

分享个人技术学习记录和跑步马拉松训练比赛、读书笔记等内容，感兴趣的朋友可以关注我的公众号「by在水一方」。

![by在水一方](http://liangjinggege.com/2020-01-26-133203.jpg)