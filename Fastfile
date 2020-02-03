
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
             "bundleId"=>"CustomerAdhocProfiles", 
             "bundleId"=>"DriverAdhocProfiles"
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
  # firim(firim_api_token:'xxx')

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
