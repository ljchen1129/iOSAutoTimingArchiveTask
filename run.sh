#!/bin/sh


echo "开始打包了"

# # 记录一下开始时间
echo `date` 

#发送钉钉通知
curl https://oapi.dingtalk.com/robot/send?access_token=xxx\
    -H 'Content-Type: application/json' \
    -d '{"msgtype": "text", 
         "text": {
              "content": "iOS 打包时间到，正在打包中，请稍后..."
         }
       }'





cd /Users/chenliangjing/Desktop/code/hedgehog

echo `pwd`

/Users/chenliangjing/.fastlane/bin/fastlane customer_hoc

echo '打包客户端完毕'

/Users/chenliangjing/.fastlane/bin/fastlane driver_hoc 

echo '打包司机端完毕'

echo 'finish'