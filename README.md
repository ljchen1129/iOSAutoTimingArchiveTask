### 前言

作为一个移动端程序员，每次 feature add 或者 bug fix 后经常要打包交付给 QA，以前传统的操作都是手动点击 `Xcode -> Product -> Archive -> Organizer -> Distrubute App -> ipa 上传到第三方内测分发平台（蒲公英、fir）-> 手动填写更新日志 -> 发送安装链接到部门群（钉钉或者企业微信）`，看起来好像很机械和繁琐，又没啥技术含量是吧......

如果能把这部分工作给自动化了就好了，每天可以省一点时间出来发呆也挺好的。需求整理一下大概是这样：

1. 能够定时触发；
2. 自动打包；
3. 自动读取某个时间段内的 git commit messge 信息当做更新日志；
4. 自动上传到第三方内测平台（蒲公英、Fir等）读取上一步中的更新日志一并上传，获取成功后的 下载链接，并自动生成安装二维码；
5. 上传完毕，将第 3、4 步中的更新日志和下载链接以及二维码图片当做消息体，自动发送该消息到部门群（钉钉或者企业微信）；

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

![image-20200126210005856](http://liangjinggege.com/2020-01-26-140400.png)



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

```ruby
default_platform(:ios)

# 网络请求依赖
require 'net/http'
require 'uri'
require 'json'

platform :ios do

  desc "打包 Customer"
  lane :customer_hoc do
    #自动增长 bulidNumber
    increment_build_number(xcodeproj: "Project.xcodeproj")
    # add actions here: https://docs.fastlane.tools/actions
    sh "fastlane adhoc --env Customer"
   end

  desc "打包 Driver"
  lane :driver_hoc do
    #自动增长 bulidNumber
    increment_build_number(xcodeproj: "Project.xcodeproj")
    # add actions here: https://docs.fastlane.tools/actions
    sh "fastlane adhoc --env Driver"
  end
     

   desc "发布指定 Target 到 Fir.im"
   lane :adhoc do
   gym(
     clean:true, #打包前clean项目
     workspace: "Project.xcworkspace",
     export_method: "ad-hoc", #导出方式
     scheme: ENV['SCHEME_NAME'], #scheme
     output_name: ENV['SCHEME_NAME']+".ipa", # ipa 文件名
     output_directory: "./ipa", #ipa的存放目录
     export_options: {
         provisioningProfiles: {
             "cn.ccmore.Project.customer"=>"CustomerAdhocProfiles", 
             "cn.ccmore.Project.driver"=>"DriverAdhocProfiles"
         }
     }
   )

  # 从 git log 中读取指定时间段内的日志当做更新日志
  #从缓存中读取上次打包时间
  lastArchiveDate = sh("cat /Users/username/Desktop/code/Project/lastArchiveDate.log")
  sh("echo 'lastArchiveDate: #{lastArchiveDate}'")

  # 当前时间
  currentDate = `date`
  sh("echo 'currentDate: #{currentDate}'")

  #更新日志
  updateLog = sh("git log --after='#{lastArchiveDate}' --before='#{currentDate}' --pretty=format:'%s\n' HEAD")
  sh("echo 'updateLog: \n#{updateLog}'")


  # 上传到 Fir
  # 前往fir.im获取 api token, 将鼠标放置右上角账号上面, 在下拉窗选择API token
  # 若使用的蒲公英, 请前往 https://www.pgyer.com/ 查看上传方法
  # 如果使用Firimfile, 此处为 firim 即可
  # firim(firim_api_token:'xxxx')

  # 多个参数 可以使用逗号(, )分离   
  answer = fir_cli api_token: "xxx", need_release_id: true, changelog: "#{updateLog}"

  # 获取更新下载二维码图片链接
  puts "上传后的结果： #{answer} "

  # 获取下载短连接
  download_url = "https://fir.im/#{answer[:short]}?release_id=#{answer[:release_id]}"
  puts "下载链接： #{download_url} "

  # 生成二维码图片  
  # pwd = sh("pwd")
  # puts "当前目录： #{pwd} "
  # qrCodeImagePath = "/Users/username/Desktop/code/Project/ipa/" + ENV['SCHEME_NAME']+"qrCode.png"
  # puts "二维码图片path： #{qrCodeImagePath} "
  # sh("qrencode -o #{qrCodeImagePath} #{download_url}")


  # 钉钉机器人
  app_patch   = "ipa/" + ENV['SCHEME_NAME']+".ipa"
  qrCodeImagePath = "/Users/username/Desktop/code/Project/ipa/" + "fir-" + ENV['SCHEME_NAME']+".png"
  puts "二维码图片path： #{qrCodeImagePath} "

  # 图片 base64 编码，并去除空行 \n 和空格
  qrcodeBase64Text = sh("openssl base64 -in #{qrCodeImagePath} | xargs echo -n | tr -d '[:space:]'")
  puts "二维码图片 base64: #{qrcodeBase64Text} "

  qrcodeBase64 = "data:image/png;base64,#{qrcodeBase64Text}"
  puts "图片 base64: #{qrcodeBase64} "

  app_version = get_ipa_info_plist_value(ipa: app_patch, key: "CFBundleShortVersionString")
  app_build_version = get_ipa_info_plist_value(ipa: app_patch, key: "CFBundleVersion")
  app_name    = get_ipa_info_plist_value(ipa: app_patch, key: "CFBundleDisplayName")
  app_url = download_url

  
  dingTalk_url = "https://oapi.dingtalk.com/robot/send?access_token=xxx"

  # 构造消息格式
  actionCard = 
  {
    "actionCard": {
        "title": "iOS #{ENV['SCHEME_NAME']} #{app_version} (#{app_build_version}) 内测版", 
        "text": "![downloadQrCode](#{qrcodeBase64}) 
 ### iOS #{ENV['SCHEME_NAME']} #{app_version} (bulid: #{app_build_version}) 内测版更新了 
 更新日志\n\n #{updateLog} \n\n ", 
        "hideAvatar": "0", 
        "btnOrientation": "0", 
        "singleTitle": "下载地址",
        "singleURL": "#{app_url}"
    }, 
    "msgtype": "actionCard"
  }

puts "发送的钉钉消息：#{actionCard} "



  uri = URI.parse(dingTalk_url)
  https = Net::HTTP.new(uri.host, uri.port)
  https.use_ssl = true

  request = Net::HTTP::Post.new(uri.request_uri)
  request.add_field('Content-Type', 'application/json')
  request.body = actionCard.to_json

  response = https.request(request)
  puts "------------------------------"
  puts "Response #{response.code} #{response.message}: #{response.body}"

end
end

```



#### 需求三、读取 git commit messge

git log 可以支持多种格式的 log 输出，其中就包括指定时间段输出。一行命令搞定：

```shell
# git shortlog 只会输出提交作者和message，并按照提交作者分类，而这正是我们所需要的
git shortlog --after="上次打包完成时间" --before="当前时间"
```

![image-20200127162137227](http://liangjinggege.com/2020-01-27-082137.png)

我们还需要保存上次打包完成的时间，使用文件就行：

```shell
# 保存
# 保存打包完成时间到日志中去
echo `date`  > "/Users/username/Desktop/code/Project/lastArchiveDate.log"

# 读取
# 读取指定时间段内的git commit log
read -r lastArchiveDate < "/Users/username/Desktop/code/Project/lastArchiveDate.log"
```



不过这是直接在 shell 中直接执行的，我们这段脚本要写到 Fastlane 打包脚本里面去的，而 Fastlane 是基于 ruby 的，所以我们得让 ruby 来执行这段 shell，ruby 执行 shell 有很多种方式，可以参考 https://stackoverflow.com/questions/2232/how-to-call-shell-commands-from-ruby 。

<img src="http://liangjinggege.com/2020-01-30-071320.png" alt="enter image description here" style="zoom:50%;" />



当然，fastlane 为我们提供了 sh 这种 Action 来执行，直接在 fastFile 文件中加入这段：

```ruby
# 从 git log 中读取指定时间段内的日志当做更新日志
#从缓存中读取上次打包时间
lastArchiveDate = sh("cat /Users/username/Desktop/code/Project/lastArchiveDate.log")
sh("echo 'lastArchiveDate: #{lastArchiveDate}'")

# 当前时间
currentDate = `date`
sh("echo 'currentDate: #{currentDate}'")

#更新日志，注意这里需要加 HEAD，不然脚本会阻塞，具体可看 https://stackoverflow.com/questions/12133583/gits-shortlog-command-is-failing-when-run-during-a-pre-commit-hook
updateLog = sh("git shortlog --after='#{lastArchiveDate}' --before='#{currentDate}' HEAD")
sh("echo 'updateLog: \n#{updateLog}'")
```



#### 需求四、自动上传到 Fir

这一步即可以完全基于 Fir 的命令行接口来实现，地址在这里 https://github.com/FIRHQ/fir-cli，也可以基于 Fastlane 的第三插件 [fastlane-plugin-fir_cli](https://github.com/FIRHQ/fastlane-plugin-fir_cli)，来实现，我这边是使用后者，相关代码如下：

```ruby
# 多个参数 可以使用逗号(, )分离   
answer = fir_cli api_token: "xxxxx", need_release_id: true, changelog: "#{updateLog}"

# 获取上传后的结果
puts "上传后的结果： #{answer} "

# 生成下载短连接
download_url = "https://fir.im/#{answer[:short]}?release_id=#{answer[:release_id]}"
puts "下载链接： #{download_url} "
```



但是这个插件暂时还没有支持将下载连接生成指定二维码图片的功能，原生的 Fir 的命令行是已经支持的，这边调研了一下，可以使用命令行二维码生成工具 [libqrencode](https://github.com/fukuchi/libqrencode) 来写，还可以指定生成图片的各种参数，相关的功能参数作用可以参考这篇 http://www.linuxintheshell.com/2012/03/01/entry-001-qrencode/，还有视频讲解。

```shell
# 基本语法
qrencode [option] [string]

# 将内容文本生成二维码图片到当前目录，也可以指定目录
qrencode -o xxx.png "内容"
```



同样，因为配置在 Fastfile 文件总，也要用 sh 来调用执行：

```ruby
# 生成的二维码图片路径
qrCodeImagePath = "/Users/username/Desktop/code/Project/ipa/" + ENV['SCHEME_NAME']+"qrCode.png"
puts "二维码图片path： #{qrCodeImagePath} "

sh("qrencode -o #{qrCodeImagePath} #{download_url}")
```



> 其实  [fastlane-plugin-fir_cli](https://github.com/FIRHQ/fastlane-plugin-fir_cli) 已经实现了下载二维码图片保存在本地了，就在 Project/ ipa 目录下，为 fir-`scheme`.png，还饶了一大弯自己使用 shell 来生成。

#### 需求五、自动发送安装消息

我这边目前使用的钉钉进行协作，可以在相关工作群使用钉钉机器人自动发送消息。找钉钉群管理员添加一下获取  token 就行。可以向这个地址 `https://oapi.dingtalk.com/robot/send?access_token=Your Token` 发送支持文本 (text)、链接 (link)、markdown(markdown)、ActionCard、FeedCard消息类型格式的消息，还可以填写需要 @ 的测试妹子们。

<img src="http://liangjinggege.com/2020-01-26-140401.png" style="zoom:33%;" />



其他企业微信好像也是可以的，可以自行去查看文档。

但是这里有个注意点，钉钉消息的图片是 markdown 格式的，但是`不支持本地路径`，也就是说我们上一步中生成的二维码图片通过 `![](xxx.png)` 是无效的，要么上传到图传获得远程链接，要么可以 base64 对图片编码，mac os 可以在命令行中使用 openssl 来操作，具体代码如下：

```ruby
# 图片 base64 编码，并去除空行 \n 和空格
qrcodeBase64Text = sh("openssl base64 -in #{qrCodeImagePath} | xargs echo -n | tr -d '[:space:]'")
puts "二维码图片 base64: #{qrcodeBase64Text} "

qrcodeBase64 = "data:image/png;base64,#{qrcodeBase64Text}"
puts "图片 base64: #{qrcodeBase64} "
```



那么在钉钉消息体里面就可以这样插入一张图片了：`![downloadQrcode](qrcodeBase64)`



### 踩坑

#### 一、定时脚本执行 /bin/sh:  xxx/run.sh: Operation not permitted

##### 原因：

<img src="http://liangjinggege.com/2020-01-26-121353.png" alt="image-20200126201353427" style="zoom:50%;" />

首先我配置的定时脚本路径在 /Users/username/Desktop/code/Project/run.sh，没有和定时任务的 Plist 配置文件在一个目录下，而配置的定时脚本声明的是 **#!/bin/sh**，意思是使用 **/bin/sh** 来解释执行，但是却没有给完全磁盘访问的权限。

##### 解决方案：

给足访问权限就行。系统偏好设置 -> 安全性与隐私-> 完全磁盘访问权限，查看是否有勾选☑️ 在定时脚本中声明的解释执行的 shell 的路径，就是**#!/bin/** 后面接的，有 bash 、sh、 zsh 等，我的是 sh。没有的话就添加进去。

![](http://liangjinggege.com/2020-01-26-140402.png)

#### 二、在定时脚本中直接执行 fastlane 打包命令出错： /Users/username/Desktop/code/Project/run.sh ： fastlane: command not found

##### 原因：

虽然 cd 到了当前项目目录，但还是报 fastlane 找不到

##### 解决方案：

使用全路径 fastlane 执行命令

```shell
/Users/username/.fastlane/bin/fastlane lane
```



#### 三、在 fastFile 中执行 sh("git shortlog --after="上次打包完成时间" --before="当前时间"") 卡住不执行

##### 原因：https://stackoverflow.com/questions/12133583/gits-shortlog-command-is-failing-when-run-during-a-pre-commit-hook

##### 解决方案：

在后面加一个 `HEAD`，改成这样：

```ruby
sh("git shortlog --after="上次打包完成时间" --before="当前时间"  HEAD" ) 
```



#### 四、终端生成二维码图片出错，PNG output is disabled at compile time. No output generated。

##### 原因：

可能 brew 版本不对，导致 [libqrencode](https://github.com/fukuchi/libqrencode) 依赖的 Libpng 不正确，可以搜一下源代码是一个 else 里面抛出来的错误，条件是 `HAVE_PNG`，所以这样猜测，提了 issue，作者也回复了， https://github.com/fukuchi/libqrencode/issues/149

![image-20200131202517576](http://liangjinggege.com/2020-01-31-122518.png)

![image-20200131202618174](http://liangjinggege.com/2020-01-31-122618.png)

##### 解决方案：

参考 http://macappstore.org/qrencode/，重新安装一下 brew，然后重装一下 qrencode

```shell
# 重装 brew
ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" < /dev/null 2> /dev/null

# 重装 qrencode
brew reinstall qrencode
```



#### 五、钉钉机器人发送文本消息不换行

<img src="http://liangjinggege.com/2020-02-02-122134.png" alt="image-20200202202133100" style="zoom:50%;" />

##### 原因：

我这边读取到的 git log 在命令行中明明是换行了的，但是在钉钉群里面显示就是没有换行，原来钉钉里面换行要两个 \n。

##### 解决方案：

使用 --pretty=format 格式化 log 输出， 在每条 git commit message 后在手动拼接一个 \n。

```shell
# 格式化 git log
git log --after='上次打包时间' --before='当前时间' --pretty=format:"%s\n"
```



### 总结

总共折腾了一两天时间，流程基本都跑通了，总体上还是很愉悦和有成就感的，以后就可以专心干其他的事情了，打包几乎无感，也不用怕忘记。nice！

效果如下：

<img src="http://liangjinggege.com/2020-01-26-125435.png" alt="image-20200126205435079" style="zoom:50%;" />

### 参考链接

1. [Mac上，执行定时任务：launchctl](https://my.oschina.net/shede333/blog/470377)
2. [Operation not permitted](http://osxdaily.com/2018/10/09/fix-operation-not-permitted-terminal-error-macos/)
3. [Fastlane](https://docs.fastlane.tools/)
4. [Git log 高级用法]([https://github.com/geeeeeeeeek/git-recipes/wiki/5.3-Git-log-%E9%AB%98%E7%BA%A7%E7%94%A8%E6%B3%95](https://github.com/geeeeeeeeek/git-recipes/wiki/5.3-Git-log-高级用法))
5. https://github.com/fukuchi/libqrencode
6. http://www.linuxintheshell.com/2012/03/01/entry-001-qrencode/
7. [钉钉开发文档](https://ding-doc.dingtalk.com/doc#/serverapi2/qf2nxq)



---

分享个人技术学习记录和跑步马拉松训练比赛、读书笔记等内容，感兴趣的朋友可以关注我的公众号「by在水一方」。

![by在水一方](http://liangjinggege.com/2020-01-26-140403.jpg)