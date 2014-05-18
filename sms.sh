#!/bin/sh
cd /media/data/dev/adt-bundle-linux-x86_64-20130729/sdk/platform-tools;
./adb shell am start -a android.intent.action.SENDTO -d sms:+33623833663 --es sms_body "SMS BODY GOES HERE" --ez exit_on_sent true;
./adb shell input keyevent 22;
./adb shell input keyevent 66;
