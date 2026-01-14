Class {
	#name : 'PhleeterOnOSX',
	#superclass : 'AppGeneratorOSXGenerator',
	#instVars : [
		'targetPlatforms'
	],
	#category : 'Phleeter-Core',
	#package : 'Phleeter-Core'
}

{ #category : 'external resources' }
PhleeterOnOSX >> addExternalDirectory: origin destination: destination [

	externalResources add: (AppGeneratorFileResource new
			 generator: self;
			 origin: origin asFileReference;
			 destination: destination;
			 beDirectory;
			 yourself)
]

{ #category : 'external resources' }
PhleeterOnOSX >> addExternalFile: origin destination: destination [

	externalResources add: (AppGeneratorFileResource new
			 generator: self;
			 origin: origin asFileReference;
			 destination: destination;
			 yourself)
]

{ #category : 'copying' }
PhleeterOnOSX >> copyIconSetIn: appDirectory [

	(appDirectory / 'Contents' / 'Resources') ensureCreateDirectory.

	(appDirectory / 'Contents' / 'Resources' / 'icon.icns') ensureDelete.
	self iconSetFile copyTo:
		appDirectory / 'Contents' / 'Resources' / 'icon.icns'.

	"Copying in the Build directory for the installer icon"
	(outputDirectory / 'disk.icns') ensureDelete.
	self diskIconSetFile copyTo: outputDirectory / 'disk.icns'
]

{ #category : 'accessing' }
PhleeterOnOSX >> defaultTargetPlatforms [

	^ { 'Darwin-arm64'. 'Darwin-x86_64'. 'Windows-x86_64' }
]

{ #category : 'accessing' }
PhleeterOnOSX >> diskIconSetFile [

	^ properties at: #DiskIconSetFile
]

{ #category : 'external resources' }
PhleeterOnOSX >> externalResourceTargetDirectory [

	^ outputDirectory / 'build_image' / 'Contents' / 'Resources'
]

{ #category : 'utilities' }
PhleeterOnOSX >> fillWithDefaults [

	super fillWithDefaults.
	properties
		at: #DeployPharoExpression ifAbsentPut: 'nil';
		at: #CodesignName ifAbsentPut: '-';
		at: #DiskIconSetFile
		ifAbsentPut: self templateDirectory / 'disk.icns'
]

{ #category : 'translating' }
PhleeterOnOSX >> generate [

	| appDirectory |
	self fillWithDefaults.
	outputDirectory ensureCreateDirectory.
	self copyExternalResources.

	appDirectory := outputDirectory / 'build_image'.
	appDirectory ensureCreateDirectory.

	self copyIconSetIn: appDirectory.
	self generatePListIn: appDirectory.
	self copyInstallerBackground.

	self generateBuildScript
]

{ #category : 'generating' }
PhleeterOnOSX >> generateBuildScript [

	outputDirectory / 'build.sh' writeStreamDo: [ :stream |
		stream truncate.
		stream nextPutAll: self mainBuildScript.
		self targetPlatforms do: [ :platform |
			stream nextPutAll: (self platformBuildScriptFor: platform) ] ]
]

{ #category : 'scripts' }
PhleeterOnOSX >> mainBuildScript [

	^ '#!/bin/bash

set -x 
set -e

IMAGE_DIR={ImageDir}
IMAGE_NAME={ImageName}
CHANGES_NAME={ChangesName}
APP_NAME={AppName}
APP_BUNDLE=$APP_NAME.app
VM_TYPE={VMType}

# To create the DMG we need the create-dmg tool, you can get it from brew
# brew install create-dmg

#Clean Up previous build
rm -f *.dmg

#Setting DPI for the background image
sips --setProperty dpiWidth 144 --setProperty dpiHeight 144 installer-background.png

# prepare build image
mkdir -p build_image/Contents/Resources
cp -f $IMAGE_DIR/*.sources build_image/Contents/Resources/
cp -f $IMAGE_DIR/$CHANGES_NAME build_image/Contents/Resources/
cp -f $IMAGE_DIR/$IMAGE_NAME build_image/Contents/Resources/

#Downloading Pharo VM
if [ ! -d "./pharo-vm-$(uname -s)-$(uname -m)" ] 
then
    mkdir pharo-vm-$(uname -s)-$(uname -m)
    pushd pharo-vm-$(uname -s)-$(uname -m)
    if [ $VM_TYPE -eq "headless" ]; then
      curl --output vm.zip https://files.pharo.org/vm/pharo-spur64-headless/$(uname -s)-$(uname -m)/{VMZipFile}
    else
      curl --output vm.zip https://files.pharo.org/vm/pharo-spur64/$(uname -s)-$(uname -m)/stable10.zip
    fi
    unzip vm.zip 
    popd
fi

#execute deploy script in pharo
pharo-vm-$(uname -s)-$(uname -m)/Pharo.app/Contents/MacOS/Pharo --headless build_image/Contents/Resources/$IMAGE_NAME eval --save {DeployPharoExpression}
' withUnixLineEndings format: properties
]

{ #category : 'scripts' }
PhleeterOnOSX >> platformBuildScriptFor: aString [

	| os |
	os := aString copyFrom: 1 to: (aString indexOf: $-).
	os = 'Darwin-' ifTrue: [
		^ self platformBuildScriptTemplateForMacOS format: (properties copy
				   at: #TargetPlatform put: aString;
				   yourself) ].
	os = 'Windows-' ifTrue: [
		^ self platformBuildScriptTemplateForWindows format:
			  (properties copy
				   at: #TargetPlatform put: aString;
				   yourself) ].
	^ self error: 'Unsupported platform ' , os
]

{ #category : 'scripts' }
PhleeterOnOSX >> platformBuildScriptTemplateForMacOS [

	^ '
##Build {TargetPlatform}

#Downloading Pharo VM for {TargetPlatform}
if [ ! -d "./pharo-vm-{TargetPlatform}" ] 
then
    mkdir pharo-vm-{TargetPlatform}
    pushd pharo-vm-{TargetPlatform}
    if [ $VM_TYPE -eq "headless" ]; then
      curl --output vm.zip https://files.pharo.org/vm/pharo-spur64-headless/{TargetPlatform}/{VMZipFile}
    else
      curl --output vm.zip https://files.pharo.org/vm/pharo-spur64/{TargetPlatform}/stable10.zip
    fi
    unzip vm.zip 
    popd
fi

#Creating DMG
rm -f -R dmg
mkdir -p dmg/$APP_BUNDLE
cp -r build_image/* ./dmg/$APP_BUNDLE/
mkdir -p ./dmg/$APP_BUNDLE/Contents/MacOS
cp -Rf pharo-vm-{TargetPlatform}/Pharo.app/Contents/MacOS/* ./dmg/$APP_BUNDLE/Contents/MacOS/
mv ./dmg/$APP_BUNDLE/Contents/MacOS/Pharo ./dmg/$APP_BUNDLE/Contents/MacOS/$APP_NAME
codesign --force --deep -s {CodesignName} dmg/$APP_BUNDLE
create-dmg \\
    --volname "$APP_NAME Installer" \\
    --volicon "disk.icns" \\
    --background "installer-background.png" \\
    --window-pos 200 120 \\
    --window-size 600 400 \\
    --icon-size 100 \\
    --icon "$APP_BUNDLE" 120 120 \\
    --hide-extension "$APP_BUNDLE" \\
    --app-drop-link 450 120 \\
    "$APP_NAME-Installer-{TargetPlatform}.dmg" \\
    "dmg/"
' withUnixLineEndings
]

{ #category : 'scripts' }
PhleeterOnOSX >> platformBuildScriptTemplateForWindows [

	^ '
if [ ! -d "./pharo-vm-{TargetPlatform}" ] 
then
    mkdir -p pharo-vm-{TargetPlatform}/
    pushd pharo-vm-{TargetPlatform}
    if [ $VM_TYPE -eq "headless" ]; then
      curl --output vm.zip https://files.pharo.org/vm/pharo-spur64-headless/{TargetPlatform}/latest10.zip
    else
      curl --output vm.zip https://files.pharo.org/vm/pharo-spur64/{TargetPlatform}/stable10.zip
    fi
    unzip vm.zip
    rm vm.zip
    popd
fi

rm -rf $APP_NAME
mkdir $APP_NAME
cp -rp pharo-vm-{TargetPlatform} $APP_NAME/Pharo

if [  ! -d "./PharoVMStart" ]
then
    curl --output PharoVMStart.zip https://viennatalk.org/builds/PharoVMStart/PharoVMStart.zip
    unzip PharoVMStart.zip
    rm PharoVMStart.zip
fi
cp -p PharoVMStart/* $APP_NAME
mv $APP_NAME/PharoVMStart.exe $APP_NAME/$APP_NAME.exe

cp -rp build_image/Contents/Resources/* $APP_NAME/

rm -f $APP_NAME-{TargetPlatform}.zip
zip -r $APP_NAME-{TargetPlatform}.zip $APP_NAME
' withUnixLineEndings
]

{ #category : 'accessing' }
PhleeterOnOSX >> targetPlatforms [

	^ targetPlatforms ifNil: [
		  targetPlatforms := self defaultTargetPlatforms ]
]

{ #category : 'accessing' }
PhleeterOnOSX >> targetPlatforms: anArrayOfString [

	targetPlatforms := anArrayOfString
]
