#!/bin/bash

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



cd /Users/username/Desktop/code/Project

echo `pwd`

/usr/local/bin/fastlane customer_hoc

echo '打包客户端完毕'

/usr/local/bin/fastlane driver_hoc 

echo '打包司机端完毕'

# 保存打包时间到日志
echo `date '+%Y-%m-%d %H:%M:%S'`  > "/Users/username/Desktop/code/Project/lastArchiveDate.log"

echo 'finish'

# 发送 @ 消息到具体某人
curl https://oapi.dingtalk.com/robot/send?access_token=xxx\
    -H 'Content-Type: application/json' \
    -d '{"msgtype": "text", 
         "text": {
              "content": "iOS 包已经更新完成，请知悉... @183xxxx0000"
         },
         "at": {
        	"atMobiles": [
            "183xxxx0000" 
        	], 
        	"isAtAll": false
    	}
       }'

