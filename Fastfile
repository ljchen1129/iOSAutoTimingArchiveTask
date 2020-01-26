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