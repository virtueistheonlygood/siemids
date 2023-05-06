#!/bin/bash
echo -n "  pia: "
ssh pi@raspberrysrv ip a show dev pia|grep inet|awk '{print$2}'|sed 's|/32||'
echo -n "  tun0: "
ssh pi@raspberrysrv ip a show dev tun0|grep inet|awk '{print$2}'|sed 's|/24||'
echo -n "  eth0: "
ssh pi@raspberrysrv ip a show dev eth0|grep inet|awk '{print$2}'|sed 's|/24||'
echo -n "  wlan0: "
ssh pi@raspberrysrv ip a show dev wlan0|grep inet|awk '{print$2}'|sed 's|/24||'
echo -n "  wlan1: "
ssh pi@raspberrysrv ip a show dev wlan1|grep inet|awk '{print$2}'|sed 's|/24||'
