		#!/bin/bash

		#命令行所在目录/Users/huanbenwang/iOS/AutoPack
		rootDir=$(dirname $0)

		projectDir="/Users/huanbenwang/pe/PrivateEquity"

		#默认target
		schemeName="PrivateEquity"

		#请求域和机构token
		settingsFile=$projectDir/${schemeName}/PreCompile.h

		#全局环境配置文件，键值staging, test, normal
		environmentConfig=$rootDir/configs/environment.plist

		#app的其它配置项
		appsConfig=$rootDir/configs/apps

		#domain请求域，0-normal；1-test；2-staging
		environment="staging"

		#请求环境
		domain=$(/usr/libexec/plistbuddy -c "Print :${environment}" ${environmentConfig})
		
		#IPA生成目录
		ipaPath=$rootDir/ipas

		#icon图标目录
		iconPath=$rootDir/icons

		#entitlements包加密信息
		entitles=$rootDir/entitlements

		#provinsions设备描述文件
		provinsions=$rootDir/provisions

		#版本号
		bundleShortVersion="1.1.1"
		#构建序列号
		bundleVersion="15"

		#打包的标签集合
		apps=("dstf" 
			# "tyzh" "hfrj" "zhtz" "jmkj"
			)
		appsLength=${#apps[*]}

		CODE_SIGN_IDENTITY="iPhone Distribution: Wongway Network Technologies Inc. (8R955L7ZKB)"

		#构建生成目录
		buildDir="build/Release-iphoneos"

		beginTime=$(date +%s)

		#创建版本IPA存放路径
		mkdir ${ipaPath}/${bundleShortVersion}-${bundleVersion}
		versionBuildPath=${ipaPath}/${bundleShortVersion}-${bundleVersion}

		#替换请求域和机构token

		for (( i = 0; i<$appsLength; i+=1));
		do
			#app的名字
			appName=${apps[${i}]}

			#APP的其它配置文件
			otherConfig=$appsConfig/${appName}.plist

			#app的token文件夹
			instToken=$(/usr/libexec/plistbuddy -c "Print :institution" ${otherConfig})
			#app安装后的展示名称
			displayName=$(/usr/libexec/plistbuddy -c "Print :name" ${otherConfig})
			#app的bundle标识符
			identifier=$(/usr/libexec/plistbuddy -c "Print :bundle" ${otherConfig})

			gtAppId=$(/usr/libexec/plistbuddy -c "Print :gtAppId" ${otherConfig})
			gtAppKey=$(/usr/libexec/plistbuddy -c "Print :gtAppKey" ${otherConfig})
			gtAppSecret=$(/usr/libexec/plistbuddy -c "Print :gtAppSecret" ${otherConfig})

			#provision File
			provisionFile=$provinsions/${appName}.mobileprovision

			#PROVISIONING_PROFILE
			security cms -D -i ${provisionFile} -o ~/temp.plist

			#打包用UUID
			PROVISIONING_PROFILE=$(defaults read ~/temp.plist UUID)

			#获取接下来的签名附加信息
			plutil -extract Entitlements xml1 ~/temp.plist -o ${entitles}/${appName}.plist

			#替换GlobalSettings文件内容
			echo '#define kInstToken @"'${instToken}'"\n#define kDomainUrl @"'${domain}'"\n#define kGtAppId @"'${gtAppId}'"\n#define kGtAppKey @"'${gtAppKey}'"\n#define kGtAppSecret @"'${gtAppSecret}'"' > $settingsFile
			
			#生成APP文件
			xcodebuild -workspace ${projectDir}/PrivateEquity.xcworkspace -scheme ${schemeName} -configuration Release clean -sdk iphoneos build CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY}" PROVISIONING_PROFILE="${PROVISIONING_PROFILE}" SYMROOT="${projectDir}/build"

			sleep 2

			if [[ $? = 0 ]]; then
				echo "Build Success"
			else
				echo "Build Error"

				exit
			fi

			#转移临时App
			rm -rf ${rootDir}/Payload

			mkdir ${rootDir}/Payload

			cp -Rf ${projectDir}/${buildDir}/${schemeName}.app ${rootDir}/Payload
			tempApp=${rootDir}/Payload/${schemeName}.app

			cp -Rf $iconPath/${appName}/* $tempApp

			if [[ $? = 0 ]]; then
				echo "Icon 替换成功"
			else
				echo "Icon 替换失败"

				exit
			fi

			defaults write $tempApp/info.plist "CFBundleName" $appName
			defaults write $tempApp/info.plist "CFBundleDisplayName" $displayName
			defaults write $tempApp/info.plist "CFBundleShortVersionString" $bundleShortVersion
			defaults write $tempApp/info.plist "CFBundleVersion" $bundleVersion
			defaults write $tempApp/info.plist "CFBundleIdentifier" $identifier

			if [[ $? = 0 ]]; then
				echo "修改 plist 成功"
			else
				echo "修改 plist 失败"

				exit
			fi

			#mobileprofinsion文件拷贝替换临时APP目录embedded.mobileprovision
			cp -f $provinsions/${appName}.mobileprovision $tempApp/embedded.mobileprovision

			#睡眠3秒，然后执行下一条
			sleep 1

			#签名
			cd $rootDir
			
			#内嵌描述文件
			mobileprovision=${tempApp}/embedded.mobileprovision

			#获取签名文件--该方法已丢弃
			# keywords='<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0">'
			# wordstart=false
			# for l in $(security cms -D -i ${mobileprovision})
			# do
			# 	if [[ $wordstart = true ]]
			# 		then
			# 		keywords=${keywords}"\n"${l}

			# 		if [[ $l = "</dict>" ]]
			# 			then
			# 			wordstart=false
			# 		fi
			# 	fi

			# 	if [[ $l = "<key>Entitlements</key>" ]]
			# 		then
			# 		wordstart=true
			# 	fi
			# done
			# keywords=${keywords}"\n</plist>"

			#写入关键签名信息
			entitle=${entitles}/${appName}.plist

			/usr/bin/codesign --force --sign "${CODE_SIGN_IDENTITY}" --entitlements ${entitle} ${tempApp}

			if [[ $? = 0 ]]; then
				echo "签名成功"
			else
				echo "签名失败"

				exit
			fi

			cd $rootDir
			xcrun -sdk iphoneos -v PackageApplication $tempApp -o ${versionBuildPath}/${displayName}-${environment}.ipa

			if [[ $? = 0 ]]; then
				echo "ipa Success"
			else
				echo "ipa Failed"
			fi

		done

		endTime=$(date +%s)

		echo -e "打包完成时间$[ endTime - beginTime ] 秒"





