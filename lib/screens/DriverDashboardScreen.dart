import 'dart:async';
import 'dart:convert';

import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:otp_text_field/otp_field.dart';
import 'package:otp_text_field/style.dart';
import 'package:taxi_driver/screens/ChatScreen.dart';
import 'package:taxi_driver/screens/DetailScreen.dart';
import 'package:taxi_driver/screens/EditProfileScreen.dart';
import 'package:taxi_driver/screens/ReviewScreen.dart';
import 'package:taxi_driver/screens/VerifyDeliveryPersonScreen.dart';
import 'package:taxi_driver/utils/Extensions/StringExtensions.dart';
import 'package:url_launcher/url_launcher.dart';

import '../components/AlertScreen.dart';
import '../components/DrawerWidget.dart';
import '../components/ExtraChargesWidget.dart';
import '../main.dart';
import '../model/CurrentRequestModel.dart';
import '../model/ExtraChargeRequestModel.dart';
import '../model/RiderModel.dart';
import '../model/UserDetailModel.dart';
import '../model/WalletDetailModel.dart';
import '../network/RestApis.dart';
import '../utils/Colors.dart';
import '../utils/Common.dart';
import '../utils/Constants.dart';
import '../utils/Extensions/AppButtonWidget.dart';
import '../utils/Extensions/ConformationDialog.dart';
import '../utils/Extensions/LiveStream.dart';
import '../utils/Extensions/app_common.dart';
import '../utils/Images.dart';
import 'BankInfoScreen.dart';
import 'EarningScreen.dart';
import 'EmergencyContactScreen.dart';
import 'LocationPermissionScreen.dart';
import 'MyRidesScreen.dart';
import 'MyWalletScreen.dart';
import 'NotificationScreen.dart';
import 'SettingScreen.dart';
import 'VehicleScreen.dart';

class DriverDashboardScreen extends StatefulWidget {
  @override
  DriverDashboardScreenState createState() => DriverDashboardScreenState();
}

class DriverDashboardScreenState extends State<DriverDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Completer<GoogleMapController> _controller = Completer();
  OtpFieldController otpController = OtpFieldController();
  late StreamSubscription<ServiceStatus> serviceStatusStream;

  List<RiderModel> riderList = [];
  OnRideRequest? servicesListData;

  UserData? riderData;
  WalletDetailModel? walletDetailModel;

  LatLng? userLatLong;
  final Set<Marker> markers = {};
  Set<Polyline> _polyLines = Set<Polyline>();
  late PolylinePoints polylinePoints;
  List<LatLng> polylineCoordinates = [];

  List<ExtraChargeRequestModel> extraChargeList = [];
  num extraChargeAmount = 0;
  late StreamSubscription<Position> positionStream;
  LocationPermission? permissionData;

  LatLng? driverLocation;
  LatLng? sourceLocation;
  LatLng? destinationLocation;

  bool isOffLine = false;
  String? otpCheck;
  String endLocationAddress = '';
  double totalDistance = 0.0;

  late BitmapDescriptor driverIcon;
  late BitmapDescriptor destinationIcon;
  late BitmapDescriptor sourceIcon;

  Timer? timerData;
  int startTime = 60;
  int end = 0;
  int duration = 0;
  int riderId = 0;

  bool locationEnable = true;
  Timer? timerUpdateLocation;

  @override
  void initState() {
    super.initState();
    init();
    locationPermission();

    log(servicesListData);
    if (sharedPref.getInt(IS_ONLINE) == 1) {
      isOffLine = true;
    }
  }

  void init() async {
    LiveStream().on(CHANGE_LANGUAGE, (p0) {
      setState(() {});
    });
    walletCheckApi();
    driverIcon = await BitmapDescriptor.fromAssetImage(ImageConfiguration(devicePixelRatio: 2.5), DriverIcon);
    mqttForUser();
    setTimeData();
    polylinePoints = PolylinePoints();

    await getAppSetting().then((value) {
      if (value.walletSetting != null) {
        value.walletSetting!.forEach((element) {
          if (element.key == PRESENT_TOPUP_AMOUNT) {
            appStore.setWalletPresetTopUpAmount(element.value ?? '10|20|30');
          }
          if (element.key == MIN_AMOUNT_TO_ADD) {
            if (element.value != null) appStore.setMinAmountToAdd(int.parse(element.value!));
          }
          if (element.key == MAX_AMOUNT_TO_ADD) {
            if (element.value != null) appStore.setMaxAmountToAdd(int.parse(element.value!));
          }
        });
      }
      if (value.rideSetting != null) {
        value.rideSetting!.forEach((element) {
          if (element.key == PRESENT_TIP_AMOUNT) {
            appStore.setWalletTipAmount(element.value ?? '10|20|30');
          }
          if (element.key == MAX_TIME_FOR_DRIVER_SECOND) {
            startTime = int.parse(element.value ?? '60');
          }
          if (element.key == APPLY_ADDITIONAL_FEE) {
            appStore.setExtraCharges(element.value ?? '0');
          }
        });
      }

      if (value.currencySetting != null) {
        appStore.setCurrencyCode(value.currencySetting!.symbol ?? currencySymbol);
        appStore.setCurrencyName(value.currencySetting!.code ?? currencyNameConst);
        appStore.setCurrencyPosition(value.currencySetting!.position ?? LEFT);
      }
      setState(() {});
    }).catchError((error) {
      log('${error.toString()}');
    });
    driverIcon = await BitmapDescriptor.fromAssetImage(ImageConfiguration(devicePixelRatio: 2.5), DriverIcon);
    sourceIcon = await BitmapDescriptor.fromAssetImage(ImageConfiguration(devicePixelRatio: 2.5), SourceIcon);
    destinationIcon = await BitmapDescriptor.fromAssetImage(ImageConfiguration(devicePixelRatio: 2.5), DestinationIcon);
    getCurrentRequest();
    if (appStore.isLoggedIn) {
      startLocationTracking();
    }
    setSourceAndDestinationIcons();
    await getAppSetting().then((value) {
      appStore.setWalletPresetTopUpAmount(value.walletSetting!.firstWhere((element) => element.key == "preset_topup_amount").value ?? '10|20|30');
      markers.add(
        Marker(
          markerId: MarkerId("DeliveryBoy"),
          position: driverLocation!,
          icon: driverIcon,
          infoWindow: InfoWindow(title: ''),
        ),
      );
    }).catchError((error) {
      log('${error.toString()}');
    });
  }

  Future<void> locationPermission() async {
    serviceStatusStream = Geolocator.getServiceStatusStream().listen((ServiceStatus status) {
      if (status == ServiceStatus.disabled) {
        locationEnable = false;
        launchScreen(navigatorKey.currentState!.overlay!.context, LocationPermissionScreen());
      } else if (status == ServiceStatus.enabled) {
        locationEnable = true;
        startLocationTracking();

        if (Navigator.canPop(navigatorKey.currentState!.overlay!.context)) {
          Navigator.pop(navigatorKey.currentState!.overlay!.context);
        }
      }
    });
  }

  Future<void> setTimeData() async {
    if (sharedPref.getString(IS_TIME2) == null) {
      duration = startTime;
      sharedPref.setString(IS_TIME2, DateTime.now().add(Duration(seconds: startTime)).toString());
    } else {
      duration = DateTime.parse(sharedPref.getString(IS_TIME2)!).difference(DateTime.now()).inSeconds;
      if (duration > 0) {
        if (sharedPref.getString(ON_RIDE_MODEL) != null) {
          servicesListData = OnRideRequest.fromJson(jsonDecode(sharedPref.getString(ON_RIDE_MODEL)!));

          setState(() {});
        }

        startTimer();
      } else {
        //timerData!.cancel();
        sharedPref.remove(IS_TIME2);
        duration = startTime;
        setState(() {});
      }
    }
  }

  Future<void> startTimer() async {
    const oneSec = const Duration(seconds: 1);
    timerData = new Timer.periodic(
      oneSec,
      (Timer timer) {
        if (duration == 0) {
          duration = startTime;
          timer.cancel();
          FlutterRingtonePlayer.stop();
          sharedPref.remove(ON_RIDE_MODEL);
          sharedPref.remove(IS_TIME2);
          servicesListData = null;
          _polyLines.clear();
          setMapPins();
          setState(() {});
          Future.delayed(Duration(seconds: 4)).then((value) {
            Map req = {
              "id": riderId,
            };
            rideRequestResPond(request: req).then((value) {}).catchError((error) {
              log(error.toString());
            });
          });
        } else {
          setState(() {
            duration--;
          });
        }
      },
    );
  }

  Future<void> setSourceAndDestinationIcons() async {
    driverIcon = await BitmapDescriptor.fromAssetImage(ImageConfiguration(devicePixelRatio: 2.5), DriverIcon);
    if (servicesListData != null)
      servicesListData!.status != IN_PROGRESS
          ? sourceIcon = await BitmapDescriptor.fromAssetImage(ImageConfiguration(devicePixelRatio: 2.5), SourceIcon)
          : destinationIcon = await BitmapDescriptor.fromAssetImage(ImageConfiguration(devicePixelRatio: 2.5), DestinationIcon);
  }

  onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  Future<void> driverStatus({int? status}) async {
    appStore.setLoading(true);
    Map req = {
      "status": "active",
      "is_online": status,
    };
    await updateStatus(req).then((value) {
      sharedPref.setInt(IS_ONLINE, value.data!.isOnline!);
      setState(() {});
      appStore.setLoading(false);
    }).catchError((error) {
      appStore.setLoading(false);

      log(error.toString());
    });
  }

  Future<void> getCurrentRequest() async {
    appStore.setLoading(true);
    log("isOnline14--->" + sharedPref.getInt(IS_ONLINE).toString());

    await getCurrentRideRequest().then((value) async {
      appStore.setLoading(false);
      if (value.onRideRequest != null) {
        appStore.currentRiderRequest = value.onRideRequest;
        servicesListData = value.onRideRequest;

        userDetail(driverId: value.onRideRequest!.riderId);

        setState(() {});

        if (servicesListData != null) {
          if (servicesListData!.status == COMPLETED && servicesListData!.isDriverRated == 0) {
            launchScreen(context, ReviewScreen(rideId: value.onRideRequest!.id!, currentData: value), pageRouteAnimation: PageRouteAnimation.Slide, isNewTask: true);
          } else if (value.payment != null && value.payment!.paymentStatus == PENDING) {
            launchScreen(context, DetailScreen(), pageRouteAnimation: PageRouteAnimation.Slide, isNewTask: true);
          }
        }
      } else {
        if (value.payment != null && value.payment!.paymentStatus == PENDING) {
          launchScreen(context, DetailScreen(), pageRouteAnimation: PageRouteAnimation.Slide, isNewTask: true);
        }
      }
      await changeStatus();
    }).catchError((error) {
      toast(error.toString());

      appStore.setLoading(false);

      servicesListData = null;
      setState(() {});
    });
  }

  Future<void> rideRequest({String? status}) async {
    appStore.setLoading(true);
    Map req = {
      "id": servicesListData!.id,
      "status": status,
    };
    await rideRequestUpdate(request: req, rideId: servicesListData!.id).then((value) async {
      appStore.setLoading(false);
      getCurrentRequest().then((value) async {
        _polyLines.clear();
        setMapPins();
        setState(() {});
      });
    }).catchError((error) {
      appStore.setLoading(false);
      log(error.toString());
    });
  }

  Future<void> rideRequestAccept({bool deCline = false}) async {
    appStore.setLoading(true);
    Map req = {
      "id": servicesListData!.id,
      if (!deCline) "driver_id": sharedPref.getInt(USER_ID),
      "is_accept": deCline ? "0" : "1",
    };
    await rideRequestResPond(request: req).then((value) async {
      appStore.setLoading(false);
      getCurrentRequest();
      if (deCline) {
        servicesListData = null;
        _polyLines.clear();
        sharedPref.remove(ON_RIDE_MODEL);
        sharedPref.remove(IS_TIME2);
        setMapPins();
        //setState(() {});
      }
    }).catchError((error) {
      appStore.setLoading(false);
      log(error.toString());
    });
  }

  Future<void> completeRideRequest() async {
    appStore.setLoading(true);
    Map req = {
      "id": servicesListData!.id,
      "service_id": servicesListData!.serviceId,
      "end_latitude": driverLocation!.latitude,
      "end_longitude": driverLocation!.longitude,
      "end_address": endLocationAddress,
      "distance": totalDistance,
      if (extraChargeList.isNotEmpty) "extra_charges": extraChargeList,
      if (extraChargeList.isNotEmpty) "extra_charges_amount": extraChargeAmount,
    };
    log(req);
    await completeRide(request: req).then((value) async {
      sourceIcon = await BitmapDescriptor.fromAssetImage(ImageConfiguration(devicePixelRatio: 2.5), SourceIcon);
      appStore.setLoading(false);
      getCurrentRequest();
    }).catchError((error) {
      appStore.setLoading(false);
      log(error.toString());
    });
  }

  Future<void> setPolyLines() async {
    if (servicesListData != null) _polyLines.clear();
    polylineCoordinates.clear();
    var result = await polylinePoints.getRouteBetweenCoordinates(
      googleMapAPIKey,
      PointLatLng(driverLocation!.latitude, driverLocation!.longitude),
      servicesListData!.status != IN_PROGRESS
          ? PointLatLng(double.parse(servicesListData!.startLatitude.validate()), double.parse(servicesListData!.startLongitude.validate()))
          : PointLatLng(double.parse(servicesListData!.endLatitude.validate()), double.parse(servicesListData!.endLongitude.validate())),
    );
    if (result.points.isNotEmpty) {
      result.points.forEach((element) {
        polylineCoordinates.add(LatLng(element.latitude, element.longitude));
      });
      _polyLines.add(
        Polyline(
          visible: true,
          width: 5,
          polylineId: PolylineId('poly'),
          color: Color.fromARGB(255, 40, 122, 198),
          points: polylineCoordinates,
        ),
      );
      setState(() {});
    }
  }

  Future<void> setMapPins() async {
    markers.clear();

    ///source pin
    MarkerId id = MarkerId("DeliveryBoy");
    markers.remove(id);
    markers.add(
      Marker(
        markerId: id,
        position: driverLocation!,
        icon: driverIcon,
        infoWindow: InfoWindow(title: ''),
      ),
    );
    if (servicesListData != null)
      servicesListData!.status != IN_PROGRESS
          ? markers.add(
              Marker(
                markerId: MarkerId('sourceLocation'),
                position: LatLng(double.parse(servicesListData!.startLatitude!), double.parse(servicesListData!.startLongitude!)),
                icon: sourceIcon,
                infoWindow: InfoWindow(title: servicesListData!.startAddress),
              ),
            )
          : markers.add(
              Marker(
                markerId: MarkerId('destinationLocation'),
                position: LatLng(double.parse(servicesListData!.endLatitude!), double.parse(servicesListData!.endLongitude!)),
                icon: destinationIcon,
                infoWindow: InfoWindow(title: servicesListData!.endAddress),
              ),
            );
  }

  /// Get Current Location
  Future<void> startLocationTracking() async {
    _polyLines.clear();
    polylineCoordinates.clear();
    await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high).then((value) async {
      await Geolocator.isLocationServiceEnabled().then((value) async {
        if (locationEnable) {
          positionStream = Geolocator.getPositionStream().listen((event) async {
            if (appStore.isLoggedIn) {
              driverLocation = LatLng(event.latitude, event.longitude);
              Map req = {
                "status": "active",
                "latitude": driverLocation!.latitude.toString(),
                "longitude": driverLocation!.longitude.toString(),
              };

              await updateStatus(req).then((value) {
                setState(() {});
              }).catchError((error) {
                log(error);
              });
              setMapPins();
              _polyLines.clear();
              polylineCoordinates.clear();
              if (servicesListData != null) setMapPins();
              if (servicesListData != null) setPolyLines();
            }
          }, onError: (error) {
            positionStream.cancel();
          });
        }
      });
    }).catchError((error) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => LocationPermissionScreen()));
    });
  }

  Future<void> userDetail({int? driverId}) async {
    await getUserDetail(userId: driverId).then((value) {
      appStore.setLoading(false);
      riderData = value.data!;
      print('akx-->' + riderData!.toJson().toString());
      setState(() {});
    }).catchError((error) {
      appStore.setLoading(false);
    });
  }

  mqttForUser() async {
    client.setProtocolV311();
    client.logging(on: true);
    client.keepAlivePeriod = 120;
    client.autoReconnect = true;

    try {
      await client.connect();
    } on NoConnectionException catch (e) {
      debugPrint(e.toString());
      client.connect();
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      client.onSubscribed = onSubscribed;

      log('connected');
      debugPrint('connected');
    } else {
      client.connect();
    }

    void onconnected() {
      debugPrint('connected');
    }

    client.subscribe('new_ride_request_' + sharedPref.getInt(USER_ID).toString(), MqttQos.atLeastOnce);
    client.subscribe('ride_request_status_' + sharedPref.getInt(USER_ID).toString(), MqttQos.atLeastOnce);

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) async {
      final MqttPublishMessage recMess = c![0].payload as MqttPublishMessage;

      final pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      log('${jsonDecode(pt)['result']}');
      if (jsonDecode(pt)['success_type'] == "new_ride_requested") {
        FlutterRingtonePlayer.play(
          fromAsset: "images/ringtone.mp3",
          android: AndroidSounds.alarm,
          ios: IosSounds.triTone,
          looping: true,
          volume: 0.1,
          asAlarm: false,
        );
        servicesListData = OnRideRequest.fromJson(jsonDecode(pt)['result']);

        sharedPref.setString(ON_RIDE_MODEL, jsonEncode(servicesListData));
        riderId = servicesListData!.id!;
        sharedPref.remove(IS_TIME2);
        setTimeData();
        startTimer();
      } else if (jsonDecode(pt)['success_type'] == "canceled") {
        FlutterRingtonePlayer.stop();
        sharedPref.remove(ON_RIDE_MODEL);
        sharedPref.remove(IS_TIME2);
        servicesListData = null;
        if (timerData != null) timerData!.cancel();
        _polyLines.clear();
        setMapPins();
        setState(() {});
      }

      print('$pt');
    });

    client.onConnected = onconnected;
  }

  void onConnected() {
    log('Connected');
  }

  void onSubscribed(String topic) {
    log('Subscription confirmed for topic $topic');
  }

  Future<void> changeStatus() async {
    if (servicesListData == null) {
      Map req = {
        "is_available": 1,
      };
      updateStatus(req).then((value) {
        //
      });
    } else {
      Map req = {
        "is_available": 0,
      };
      updateStatus(req).then((value) {
        //
      });
    }
  }

  /// WalletCheck
  Future<void> walletCheckApi() async {
    await walletDetailApi().then((value) async {
      if (value.totalAmount! >= value.minAmountToGetRide!) {
        //
      } else {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) {
            return AlertDialog(
              content: Container(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(walletGIF, height: 150, fit: BoxFit.contain),
                    SizedBox(height: 8),
                    Text(language.walletLessAmountMsg, style: primaryTextStyle(), textAlign: TextAlign.justify),
                    SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: AppButtonWidget(
                            padding: EdgeInsets.zero,
                            color: Colors.red,
                            text: language.no,
                            textColor: Colors.white,
                            onTap: () {
                              Navigator.pop(context);
                            },
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: AppButtonWidget(
                            padding: EdgeInsets.zero,
                            text: language.yes,
                            onTap: () {
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      }
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void dispose() {
    if (timerData != null) {
      timerData!.cancel();
    }
    if (timerData == null) {
      sharedPref.getString(IS_TIME2);
    }
    FlutterRingtonePlayer.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Map req = {
          "is_available": 0,
        };
        updateStatus(req).then((value) {
          //
        });
        return true;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        key: _scaffoldKey,
        drawer: Drawer(
          backgroundColor: Colors.white,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 35),
                Center(
                  child: Container(
                    padding: EdgeInsets.only(right: 8),
                    child: Observer(builder: (context) {
                      return Column(
                        children: [
                          ClipRRect(
                            borderRadius: radius(16),
                            child: commonCachedNetworkImage(appStore.userProfile.validate().validate(), height: 70, width: 70, fit: BoxFit.cover),
                          ),
                          SizedBox(height: 8),
                          sharedPref.getString(LOGIN_TYPE) != 'mobile' && sharedPref.getString(LOGIN_TYPE) != null
                              ? Text(sharedPref.getString(USER_NAME).validate(), style: boldTextStyle())
                              : Text(sharedPref.getString(FIRST_NAME).validate(), style: boldTextStyle()),
                          SizedBox(height: 4),
                          Text(appStore.userEmail, style: secondaryTextStyle()),
                        ],
                      );
                    }),
                  ),
                ),
                Divider(thickness: 1, height: 40),
                DrawerWidget(
                    title: language.profile,
                    iconData: ic_my_profile,
                    onTap: () {
                      Navigator.pop(context);
                      launchScreen(context, EditProfileScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                    }),
                DrawerWidget(
                    title: language.rides,
                    iconData: ic_my_rides,
                    onTap: () {
                      Navigator.pop(context);
                      launchScreen(context, MyRidesScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                    }),
                DrawerWidget(
                    title: language.vehicleInfo,
                    iconData: ic_vehical_detail,
                    onTap: () {
                      Navigator.pop(context);
                      launchScreen(context, VehicleScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                    }),
                DrawerWidget(
                    title: language.wallet,
                    iconData: ic_my_wallet,
                    onTap: () {
                      Navigator.pop(context);
                      launchScreen(context, MyWalletScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                    }),
                DrawerWidget(
                    title: language.emergencyContacts,
                    iconData: ic_emergency,
                    onTap: () {
                      Navigator.pop(context);
                      launchScreen(context, EmergencyContactScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                    }),
                DrawerWidget(
                    title: language.earnings,
                    iconData: ic_wallet,
                    onTap: () {
                      Navigator.pop(context);
                      launchScreen(context, EarningScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                    }),
                DrawerWidget(
                    title: language.documents,
                    iconData: ic_verify_document,
                    onTap: () {
                      Navigator.pop(context);
                      launchScreen(context, VerifyDeliveryPersonScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                    }),
                DrawerWidget(
                    title: language.bankInfo,
                    iconData: ic_update_bank_info,
                    onTap: () {
                      Navigator.pop(context);
                      launchScreen(context, BankInfoScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                    }),
                DrawerWidget(
                    title: language.settings,
                    iconData: ic_setting,
                    onTap: () {
                      launchScreen(context, SettingScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
                    }),
                SizedBox(height: 16),
                Center(
                  child: AppButtonWidget(
                    text: language.logOut,
                    color: primaryColor,
                    textStyle: boldTextStyle(color: Colors.white),
                    onTap: () async {
                      await showConfirmDialogCustom(_scaffoldKey.currentState!.context,
                          primaryColor: primaryColor,
                          dialogType: DialogType.CONFIRMATION,
                          title: language.areYouSureYouWantToLogoutThisApp,
                          positiveText: language.yes,
                          negativeText: language.no, onAccept: (v) async {
                        await driverStatus(status: 0);
                        await Future.delayed(Duration(milliseconds: 500));
                        await logout();
                      });
                    },
                  ),
                )
              ],
            ),
          ),
        ),
        appBar: AppBar(
          actions: [
            IconButton(
              onPressed: () {
                launchScreen(context, NotificationScreen(), pageRouteAnimation: PageRouteAnimation.Slide);
              },
              icon: Icon(Ionicons.notifications_outline),
            ),
          ],
        ),
        body: driverLocation != null
            ? Stack(
                children: [
                  GoogleMap(
                    mapToolbarEnabled: false,
                    zoomControlsEnabled: false,
                    myLocationEnabled: true,
                    onMapCreated: onMapCreated,
                    initialCameraPosition: CameraPosition(target: driverLocation!, zoom: 11.0),
                    markers: markers,
                    mapType: MapType.normal,
                    polylines: _polyLines,
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 40,
                    child: FlutterSwitch(
                      value: isOffLine,
                      width: 90,
                      height: 35,
                      toggleSize: 25,
                      borderRadius: 30.0,
                      padding: 6.0,
                      inactiveText: language.offLine,
                      activeText: language.online,
                      showOnOff: true,
                      activeTextColor: Colors.green,
                      inactiveTextColor: Colors.black,
                      activeIcon: ImageIcon(AssetImage(ic_green_car), color: Colors.white, size: 40),
                      inactiveIcon: ImageIcon(AssetImage(ic_red_car), color: Colors.white, size: 40),
                      activeColor: Colors.white,
                      activeToggleColor: Colors.green,
                      inactiveToggleColor: Colors.red,
                      inactiveColor: Colors.white,
                      onToggle: (value) async {
                        await showConfirmDialogCustom(
                            dialogType: DialogType.CONFIRMATION, primaryColor: primaryColor, title: isOffLine ? language.areYouCertainOffline : language.areYouCertainOnline, context, onAccept: (v) {
                          driverStatus(status: isOffLine ? 0 : 1);
                          isOffLine = value;
                          setState(() {});
                        });
                      },
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Align(
                      alignment: Alignment.center,
                      child: Container(
                        margin: EdgeInsets.only(top: 16),
                        padding: EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.2), spreadRadius: 1),
                          ],
                          borderRadius: BorderRadius.circular(defaultRadius),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              alignment: Alignment.center,
                              margin: EdgeInsets.only(right: 8),
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(color: isOffLine ? Colors.green : Colors.grey, shape: BoxShape.circle),
                            ),
                            Text(isOffLine ? language.youAreOnlineNow : language.youAreOfflineNow, style: secondaryTextStyle(color: primaryColor)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  servicesListData != null
                      ? servicesListData!.status != null && servicesListData!.status == NEW_RIDE_REQUESTED
                          ? SizedBox.expand(
                              child: Stack(
                                children: [
                                  DraggableScrollableSheet(
                                    initialChildSize: 0.40,
                                    minChildSize: 0.40,
                                    builder: (
                                      BuildContext context,
                                      ScrollController scrollController,
                                    ) {
                                      scrollController.addListener(() {
                                        //
                                      });
                                      return servicesListData != null
                                          ? Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.only(topLeft: Radius.circular(defaultRadius), topRight: Radius.circular(defaultRadius)),
                                              ),
                                              child: SingleChildScrollView(
                                                controller: scrollController,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Align(
                                                      alignment: Alignment.center,
                                                      child: Container(
                                                        margin: EdgeInsets.only(top: 16),
                                                        height: 6,
                                                        width: 60,
                                                        decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(defaultRadius)),
                                                        alignment: Alignment.center,
                                                      ),
                                                    ),
                                                    SizedBox(height: 16),
                                                    Padding(
                                                      padding: EdgeInsets.only(left: 16),
                                                      child: Text(language.requests, style: primaryTextStyle(size: 18)),
                                                    ),
                                                    SizedBox(height: 8),
                                                    Container(
                                                      margin: EdgeInsets.only(top: 8, bottom: 8, left: 16, right: 16),
                                                      width: MediaQuery.of(context).size.width,
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius: BorderRadius.circular(defaultRadius),
                                                        boxShadow: [
                                                          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 3),
                                                        ],
                                                      ),
                                                      child: Padding(
                                                        padding: EdgeInsets.all(10),
                                                        child: Column(
                                                          children: [
                                                            Row(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                ClipRRect(
                                                                  borderRadius: BorderRadius.circular(defaultRadius),
                                                                  child: commonCachedNetworkImage(servicesListData!.riderProfileImage.validate(), height: 35, width: 35, fit: BoxFit.cover),
                                                                ),
                                                                SizedBox(width: 12),
                                                                Expanded(
                                                                  child: Column(
                                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                                    children: [
                                                                      Text('${servicesListData!.riderName}', style: boldTextStyle(size: 14)),
                                                                      SizedBox(height: 4),
                                                                      Text('${servicesListData!.riderEmail.validate()}', style: secondaryTextStyle()),
                                                                    ],
                                                                  ),
                                                                ),
                                                                Container(
                                                                  decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(defaultRadius)),
                                                                  padding: EdgeInsets.all(6),
                                                                  child: Text("$duration", style: boldTextStyle(color: Colors.white)),
                                                                )
                                                              ],
                                                            ),
                                                            SizedBox(height: 16),
                                                            Divider(color: Colors.grey.withOpacity(0.5), height: 0, indent: 15, endIndent: 15),
                                                            SizedBox(height: 16),
                                                            Row(
                                                              children: [
                                                                Column(
                                                                  children: [
                                                                    Icon(Icons.near_me, color: Colors.green, size: 18),
                                                                    SizedBox(height: 2),
                                                                    SizedBox(
                                                                      height: 34,
                                                                      child: DottedLine(
                                                                        direction: Axis.vertical,
                                                                        lineLength: double.infinity,
                                                                        lineThickness: 1,
                                                                        dashLength: 2,
                                                                        dashColor: primaryColor,
                                                                      ),
                                                                    ),
                                                                    SizedBox(height: 2),
                                                                    Icon(Icons.location_on, color: Colors.red, size: 18),
                                                                  ],
                                                                ),
                                                                SizedBox(width: 16),
                                                                Expanded(
                                                                  child: Column(
                                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                                    children: [
                                                                      SizedBox(height: 2),
                                                                      Text(servicesListData!.startAddress.validate(), style: primaryTextStyle(size: 14), maxLines: 2),
                                                                      SizedBox(height: 22),
                                                                      Text(servicesListData!.endAddress.validate(), style: primaryTextStyle(size: 14), maxLines: 2),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            SizedBox(height: 20),
                                                            Divider(color: Colors.grey.withOpacity(0.5), height: 0, indent: 15, endIndent: 15),
                                                            SizedBox(height: 20),
                                                            Row(
                                                              children: [
                                                                Expanded(
                                                                  child: inkWellWidget(
                                                                    onTap: () {
                                                                      showConfirmDialogCustom(
                                                                          dialogType: DialogType.DELETE,
                                                                          primaryColor: primaryColor,
                                                                          title: language.areYouSureYouWantToCancelThisRequest,
                                                                          positiveText: language.yes,
                                                                          negativeText: language.no,
                                                                          context, onAccept: (v) {
                                                                        timerData!.cancel();
                                                                        FlutterRingtonePlayer.stop();
                                                                        sharedPref.remove(ON_RIDE_MODEL);
                                                                        sharedPref.remove(IS_TIME2);
                                                                        rideRequestAccept(deCline: true);
                                                                      });
                                                                    },
                                                                    child: Container(
                                                                      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                                                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(defaultRadius), border: Border.all(color: Colors.red)),
                                                                      child: Text(language.decline, style: boldTextStyle(color: Colors.red), textAlign: TextAlign.center),
                                                                    ),
                                                                  ),
                                                                ),
                                                                SizedBox(width: 16),
                                                                Expanded(
                                                                  child: AppButtonWidget(
                                                                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                                                    text: language.accept,
                                                                    shapeBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(defaultRadius)),
                                                                    color: primaryColor,
                                                                    textStyle: boldTextStyle(color: Colors.white),
                                                                    onTap: () {
                                                                      showConfirmDialogCustom(
                                                                          primaryColor: primaryColor,
                                                                          dialogType: DialogType.ACCEPT,
                                                                          positiveText: language.yes,
                                                                          negativeText: language.no,
                                                                          title: language.areYouSureYouWantToAcceptThisRequest,
                                                                          context, onAccept: (v) {
                                                                        timerData!.cancel();
                                                                        FlutterRingtonePlayer.stop();
                                                                        sharedPref.remove(IS_TIME2);
                                                                        sharedPref.remove(ON_RIDE_MODEL);
                                                                        rideRequestAccept();
                                                                      });
                                                                    },
                                                                  ),
                                                                ),
                                                              ],
                                                            )
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                          : SizedBox();
                                    },
                                  ),
                                  Observer(builder: (context) {
                                    return appStore.isLoading ? loaderWidget() : SizedBox();
                                  })
                                ],
                              ),
                            )
                          : Positioned(
                              bottom: 0,
                              child: Container(
                                width: MediaQuery.of(context).size.width,
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.only(topLeft: Radius.circular(defaultRadius), topRight: Radius.circular(defaultRadius)),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(defaultRadius),
                                          child: commonCachedNetworkImage(servicesListData!.riderProfileImage, height: 38, width: 38, fit: BoxFit.cover),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('${servicesListData!.riderName}', style: boldTextStyle(size: 14)),
                                              SizedBox(height: 4),
                                              Text('${servicesListData!.riderEmail.validate()}', style: secondaryTextStyle()),
                                            ],
                                          ),
                                        ),
                                        inkWellWidget(
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (_) {
                                                return AlertDialog(
                                                  contentPadding: EdgeInsets.all(0),
                                                  content: AlertScreen(rideId: servicesListData!.id, regionId: servicesListData!.regionId),
                                                );
                                              },
                                            );
                                          },
                                          child: Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(defaultRadius)),
                                            child: Text(language.sos, style: boldTextStyle(color: Colors.white)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 16),
                                    Divider(color: Colors.grey.withOpacity(0.5), height: 0, indent: 15, endIndent: 15),
                                    SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Column(
                                          children: [
                                            Icon(Icons.near_me, color: Colors.green, size: 18),
                                            SizedBox(height: 2),
                                            SizedBox(
                                              height: 34,
                                              child: DottedLine(
                                                direction: Axis.vertical,
                                                lineLength: double.infinity,
                                                lineThickness: 1,
                                                dashLength: 2,
                                                dashColor: primaryColor,
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Icon(Icons.location_on, color: Colors.red, size: 18),
                                          ],
                                        ),
                                        SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              SizedBox(height: 2),
                                              Text(servicesListData!.startAddress ?? ''.validate(), style: primaryTextStyle(size: 14), maxLines: 2),
                                              SizedBox(height: 22),
                                              Text(servicesListData!.endAddress ?? '', style: primaryTextStyle(size: 14), maxLines: 2),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 16),
                                    Divider(color: Colors.grey.withOpacity(0.5), height: 0, indent: 15, endIndent: 15),
                                    SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: servicesListData!.status != IN_PROGRESS ? MainAxisAlignment.spaceAround : MainAxisAlignment.spaceEvenly,
                                      children: [
                                        inkWellWidget(
                                          onTap: () {
                                            if (servicesListData!.isRideForOther == 1) {
                                              launchUrl(Uri.parse('tel:${servicesListData!.otherRiderData!.conatctNumber}'), mode: LaunchMode.externalApplication);
                                            } else {
                                              launchUrl(Uri.parse('tel:${servicesListData!.riderContactNumber}'), mode: LaunchMode.externalApplication);
                                            }
                                          },
                                          child: Column(
                                            children: [
                                              Icon(Icons.call, size: 25, color: primaryColor),
                                              SizedBox(height: 4),
                                              Text(language.call, style: secondaryTextStyle()),
                                            ],
                                          ),
                                        ),
                                        inkWellWidget(
                                          onTap: () {
                                            if (riderData != null) {
                                              log(riderData!.username);
                                              launchScreen(context, ChatScreen(userData: riderData));
                                            }
                                          },
                                          child: Column(
                                            children: [
                                              Icon(Icons.chat, size: 25, color: primaryColor),
                                              SizedBox(height: 4),
                                              Text(language.chat, style: secondaryTextStyle()),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (servicesListData!.status == IN_PROGRESS) SizedBox(height: 16),
                                    if (servicesListData!.status == IN_PROGRESS)
                                      if (appStore.extraChargeValue != null)
                                        Observer(builder: (context) {
                                          return Visibility(
                                            visible: int.parse(appStore.extraChargeValue!) != 0,
                                            child: inkWellWidget(
                                              onTap: () async {
                                                List<ExtraChargeRequestModel>? extraChargeListData = await showModalBottomSheet(
                                                  isScrollControlled: true,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(defaultRadius), topRight: Radius.circular(defaultRadius))),
                                                  context: context,
                                                  builder: (_) {
                                                    return Padding(
                                                      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                                                      child: ExtraChargesWidget(data: extraChargeList),
                                                    );
                                                  },
                                                );
                                                if (extraChargeListData != null) {
                                                  extraChargeAmount = 0;
                                                  extraChargeList.clear();
                                                  extraChargeListData.forEach((element) {
                                                    extraChargeAmount = extraChargeAmount + element.value!;
                                                    extraChargeList = extraChargeListData;
                                                  });
                                                }
                                              },
                                              child: Padding(
                                                  padding: EdgeInsets.only(top: 10),
                                                  child: Column(
                                                    children: [
                                                      Divider(color: Colors.grey.withOpacity(0.5), height: 0, indent: 15, endIndent: 15),
                                                      Padding(
                                                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                                        child: Row(
                                                          children: [
                                                            Icon(Icons.add),
                                                            SizedBox(width: 16),
                                                            Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Text(language.extraFees, style: primaryTextStyle()),
                                                                SizedBox(height: 2),
                                                                if (extraChargeAmount != 0)
                                                                  Text('${language.extraCharges} ${extraChargeAmount.toString()}', style: secondaryTextStyle(color: Colors.green)),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  )),
                                            ),
                                          );
                                        }),
                                    SizedBox(height: 16),
                                    AppButtonWidget(
                                      width: MediaQuery.of(context).size.width,
                                      text: buttonText(status: servicesListData!.status),
                                      color: primaryColor,
                                      textStyle: boldTextStyle(color: Colors.white),
                                      onTap: () async {
                                        if (await checkPermission()) {
                                          if (servicesListData!.status == ACCEPTED) {
                                            showConfirmDialogCustom(
                                                primaryColor: primaryColor,
                                                positiveText: language.yes,
                                                negativeText: language.no,
                                                dialogType: DialogType.CONFIRMATION,
                                                title: language.areYouSureYouWantToArriving,
                                                context, onAccept: (v) {
                                              rideRequest(status: ARRIVING);
                                            });
                                          } else if (servicesListData!.status == ARRIVING) {
                                            showConfirmDialogCustom(
                                                primaryColor: primaryColor,
                                                positiveText: language.yes,
                                                negativeText: language.no,
                                                dialogType: DialogType.CONFIRMATION,
                                                title: language.areYouSureYouWantToArrived,
                                                context, onAccept: (v) {
                                              rideRequest(status: ARRIVED);
                                            });
                                          } else if (servicesListData!.status == ARRIVED) {
                                            showDialog(
                                              context: context,
                                              builder: (_) {
                                                return AlertDialog(
                                                  content: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Align(
                                                        alignment: Alignment.topRight,
                                                        child: inkWellWidget(
                                                          onTap: () {
                                                            Navigator.pop(context);
                                                          },
                                                          child: Container(
                                                            padding: EdgeInsets.all(4),
                                                            decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                                                            child: Icon(Icons.close, size: 20, color: Colors.white),
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(height: 8),
                                                      Center(
                                                        child: Text(language.enterOtp, style: boldTextStyle(), textAlign: TextAlign.center),
                                                      ),
                                                      SizedBox(height: 16),
                                                      Text(
                                                        language.enterTheOtpDisplayInCustomersMobileToStartTheRide,
                                                        style: secondaryTextStyle(size: 12),
                                                        textAlign: TextAlign.center,
                                                      ),
                                                      SizedBox(height: 16),
                                                      OTPTextField(
                                                        controller: otpController,
                                                        length: 4,
                                                        width: MediaQuery.of(context).size.width,
                                                        fieldWidth: 40,
                                                        style: primaryTextStyle(),
                                                        textFieldAlignment: MainAxisAlignment.spaceAround,
                                                        fieldStyle: FieldStyle.box,
                                                        onCompleted: (val) {
                                                          otpCheck = val;
                                                        },
                                                        onChanged: (s) {
                                                          //
                                                        },
                                                      ),
                                                      SizedBox(height: 16),
                                                      AppButtonWidget(
                                                        width: MediaQuery.of(context).size.width,
                                                        text: language.confirm,
                                                        onTap: () {
                                                          if (otpCheck == null || otpCheck != servicesListData!.otp) {
                                                            return toast(language.pleaseEnterValidOtp);
                                                          } else {
                                                            Navigator.pop(context);
                                                            rideRequest(status: IN_PROGRESS);
                                                          }
                                                        },
                                                      )
                                                    ],
                                                  ),
                                                );
                                              },
                                            );
                                          } else if (servicesListData!.status == IN_PROGRESS) {
                                            showConfirmDialogCustom(
                                                primaryColor: primaryColor,
                                                dialogType: DialogType.ACCEPT,
                                                title: language.finishMsg,
                                                context,
                                                positiveText: language.yes,
                                                negativeText: language.no, onAccept: (v) {
                                              appStore.setLoading(true);
                                              getUserLocation().then((value) async {
                                                totalDistance = await calculateDistance(double.parse(servicesListData!.startLatitude.validate()),
                                                    double.parse(servicesListData!.startLongitude.validate()), driverLocation!.latitude, driverLocation!.longitude);
                                                await completeRideRequest();
                                              });
                                            });
                                          }
                                        }
                                      },
                                    )
                                  ],
                                ),
                              ),
                            )
                      : SizedBox(),
                  Visibility(
                    visible: appStore.isLoading,
                    child: loaderWidget(),
                  ),
                ],
              )
            : loaderWidget(),
      ),
    );
  }

  Future<void> getUserLocation() async {
    List<Placemark> placemarks = await placemarkFromCoordinates(driverLocation!.latitude, driverLocation!.longitude);
    Placemark place = placemarks[0];
    endLocationAddress = '${place.street},${place.subLocality},${place.thoroughfare},${place.locality}';
  }
}
