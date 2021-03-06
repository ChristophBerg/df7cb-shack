#!/bin/sh

# configure sdrangel and LimeSDR for QO-100

set -eux

while getopts "k" opt ; do
    case $opt in
        k) killall sdrangel; sleep 1 ;;
        *) exit 5 ;;
    esac
done
# shift away args
shift $(($OPTIND - 1))

API="http://127.0.0.1:8091/sdrangel"
DEVICESET="$API/deviceset"

# create virtual soundcards
for card in tx0 rx1 rx2; do
  if ! pacmd list-sinks | grep -q "name: <$card>"; then
    echo "Adding pulseaudio sink $card ..."
    pacmd load-module module-null-sink sink_name=$card sink_properties=device.description=$card
  fi
done

# wait for sdrangel to start

if ! SDRPID=$(pidof sdrangel); then
  sdrangel &
  SDRPID="$!"
  while ! curl -f $API; do
    sleep 1
  done
  sleep 10
fi

# add TX device set
#curl -fX PUT   --data @rxdevice-type.json $DEVICESET/0/device
if ! curl -sf $DEVICESET/1; then
  curl -fX POST  --data direction=1 $DEVICESET
fi
curl -fX PUT   --data @txdevice-type.json $DEVICESET/1/device

# configure RX device set
curl -fX PATCH --data @rxdevice.json $DEVICESET/0/device/settings
curl -fX PATCH --data @rxspectrum.json $DEVICESET/0/spectrum/settings

# configure TX device set
curl -fX PATCH --data @txdevice.json $DEVICESET/1/device/settings
curl -fX PATCH --data @txspectrum.json $DEVICESET/1/spectrum/settings

# activate device set (in this order, or else the TX frequency gets messed up)
curl -fX POST  $DEVICESET/1/device/run
curl -fX POST  $DEVICESET/0/device/run

# configure channels
if ! curl -sf $DEVICESET/0/channel/0/settings; then
  curl -fX POST --data @rx0.json $DEVICESET/0/channel
fi
curl -fX PATCH --data @rx0.json $DEVICESET/0/channel/0/settings
if ! curl -sf $DEVICESET/1/channel/0/settings; then
  curl -fX POST  --data @tx0.json $DEVICESET/1/channel
fi
curl -fX PATCH --data @tx0.json $DEVICESET/1/channel/0/settings

if ! curl -sf $DEVICESET/0/channel/1/settings; then
  curl -fX POST --data @rx1.json $DEVICESET/0/channel
fi
curl -fX PATCH --data @rx1.json $DEVICESET/0/channel/1/settings
#curl -fX POST  --data @tx1.json $DEVICESET/1/channel
#curl -fX PATCH --data @tx1.json $DEVICESET/1/channel/1/settings

if ! curl -sf $DEVICESET/0/channel/2/settings; then
  curl -fX POST --data @rx2.json $DEVICESET/0/channel
fi
curl -fX PATCH --data @rx2.json $DEVICESET/0/channel/2/settings
#curl -fX POST  --data @tx2.json $DEVICESET/1/channel
#curl -fX PATCH --data @tx2.json $DEVICESET/1/channel/2/settings

# set focus on RX device
curl -fX PATCH $DEVICESET/0/focus

systemctl --user start midiangel.service
