import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../main.dart';

const mAppName = 'Mighty Driver';
var errorThisFieldRequired = 'This field is required';

const googleMapAPIKey = 'AIzaSyDvcZMVbQCbBa_kheOKSusz-h6Md_bXAFw';

final client = MqttServerClient.withPort("broker.hivemq.com", "", 1883);

const DOMAIN_URL =
    'http://192.168.1.102:80/mightytaxi'; // Don't add slash at the end of the url
// const DOMAIN_URL = 'http://192.168.1.230/mobile/taxiapp'; // Don't add slash at the end of the url
const mBaseUrl = "$DOMAIN_URL/api/";

const mOneSignalAppIdDriver = 'ADD ONESIGNAL KEY OF DRIVER';
const mOneSignalRestKeyDriver = 'ADD ONESIGNAL REST API KEY OF DRIVER ';

const mOneSignalAppIdRider = 'ADD ONESIGNAL APP KEY OF RIDER';
const mOneSignalRestKeyRider = 'ADD ONESIGNAL REST API KEY OF RIDER';

const PRESENT_TOP_UP_AMOUNT_CONST = '10|20|30';

const passwordLengthGlobal = 8;
const defaultRadius = 10.0;
const defaultSmallRadius = 6.0;

const textPrimarySizeGlobal = 16.00;
const textBoldSizeGlobal = 16.00;
const textSecondarySizeGlobal = 14.00;

double tabletBreakpointGlobal = 600.0;
double desktopBreakpointGlobal = 720.0;
double statisticsItemWidth = 230.0;
double defaultAppButtonElevation = 4.0;

bool enableAppButtonScaleAnimationGlobal = true;
int? appButtonScaleAnimationDurationGlobal;
ShapeBorder? defaultAppButtonShapeBorder;

var customDialogHeight = 140.0;
var customDialogWidth = 220.0;

enum ThemeModes { SystemDefault, Light, Dark }

const LoginTypeApp = 'app';
const LoginTypeGoogle = 'google';
const LoginTypeOTP = 'otp';
const LoginTypeApple = 'apple';

const currencySymbol = '\$';
const currencyNameConst = 'usd';
const defaultCountryCode = '+91';
const digitAfterDecimal = 2;

/// SharedReference keys

const REMEMBER_ME = 'REMEMBER_ME';
const IS_FIRST_TIME = 'IS_FIRST_TIME';
const IS_LOGGED_IN = 'IS_LOGGED_IN';

const ON_RIDE_MODEL = 'ON_RIDE_MODEL';
const IS_TIME2 = 'IS_TIME2';

const USER_ID = 'USER_ID';
const FIRST_NAME = 'FIRST_NAME';
const LAST_NAME = 'LAST_NAME';
const TOKEN = 'TOKEN';
const USER_EMAIL = 'USER_EMAIL';
const USER_TOKEN = 'USER_TOKEN';
const USER_PROFILE_PHOTO = 'USER_PROFILE_PHOTO';
const USER_TYPE = 'USER_TYPE';
const USER_NAME = 'USER_NAME';
const USER_PASSWORD = 'USER_PASSWORD';
const USER_ADDRESS = 'USER_ADDRESS';
const STATUS = 'STATUS';
const CONTACT_NUMBER = 'CONTACT_NUMBER';
const PLAYER_ID = 'PLAYER_ID';
const UID = 'UID';
const ADDRESS = 'ADDRESS';
const IS_OTP = 'IS_OTP';
const IS_GOOGLE = 'IS_GOOGLE';
const GENDER = 'GENDER';
const IS_ONLINE = 'IS_ONLINE';
const IS_Verified_Driver = 'is_verified_driver';
const ADMIN = 'admin';
const DRIVER = 'driver';
const RIDER = 'rider';

/// Taxi Status
const IN_ACTIVE = 'inactive';
const PENDING = 'pending';
const BANNED = 'banned';
const REJECT = 'reject';

/// Wallet keys
const CREDIT = 'credit';
const DEBIT = 'debit';

const PAYMENT_TYPE_STRIPE = 'stripe';
const PAYMENT_TYPE_RAZORPAY = 'razorpay';
const PAYMENT_TYPE_PAYSTACK = 'paystack';
const PAYMENT_TYPE_FLUTTERWAVE = 'flutterwave';
const PAYMENT_TYPE_PAYPAL = 'paypal';
const PAYMENT_TYPE_PAYTABS = 'paytabs';
const PAYMENT_TYPE_MERCADOPAGO = 'mercadopago';
const PAYMENT_TYPE_PAYTM = 'paytm';
const PAYMENT_TYPE_MYFATOORAH = 'myfatoorah';

const CASH = 'cash';
const Wallet = 'wallet';

const stripeURL = 'https://api.stripe.com/v1/payment_intents';

/// My Rides Status
const UPCOMING = 'upcoming';
const NEW_RIDE_REQUESTED = 'new_ride_requested';
const ACCEPTED = 'accepted';
const ARRIVING = 'arriving';
const ACTIVE = 'active';
const ARRIVED = 'arrived';
const IN_PROGRESS = 'in_progress';
const CANCELED = 'canceled';
const COMPLETED = 'completed';
const COMPLAIN_COMMENT = "complaintcomment";

///FireBase Collection Name
const MESSAGES_COLLECTION = "messages";
const USER_COLLECTION = "users";
const CONTACT_COLLECTION = "contact";
const CHAT_DATA_IMAGES = "chatImages";

const IS_ENTER_KEY = "IS_ENTER_KEY";
const SELECTED_WALLPAPER = "SELECTED_WALLPAPER";
const PER_PAGE_CHAT_COUNT = 50;
const PAYMENT_PENDING = 'pending';
const PAYMENT_FAILED = 'failed';
const PAYMENT_PAID = 'paid';
const SELECTED_LANGUAGE_CODE = 'selected_language_code';
const THEME_MODE_INDEX = 'theme_mode_index';
const CHANGE_LANGUAGE = 'CHANGE_LANGUAGE';
const CHANGE_MONEY = 'CHANGE_MONEY';
const LOGIN_TYPE = 'login_type';

const TEXT = "TEXT";
const IMAGE = "IMAGE";

const VIDEO = "VIDEO";
const AUDIO = "AUDIO";

const FIXED_CHARGES = "fixed_charges";
const MIN_DISTANCE = "min_distance";
const MIN_WEIGHT = "min_weight";
const PER_DISTANCE_CHARGE = "per_distance_charges";
const PER_WEIGHT_CHARGE = "per_weight_charges";

const CHARGE_TYPE_FIXED = 'fixed';
const CHARGE_TYPE_PERCENTAGE = 'percentage';
const CASH_WALLET = 'cash_wallet';
const MALE = 'male';
const FEMALE = 'female';
const OTHER = 'other';
const LEFT = 'left';

/// app setting key
const CLOCK = 'clock';
const PRESENT_TOPUP_AMOUNT = 'preset_topup_amount';
const PRESENT_TIP_AMOUNT = 'preset_tip_amount';
const MAX_TIME_FOR_RIDER_MINUTE =
    'max_time_for_find_drivers_for_regular_ride_in_minute';
const MAX_TIME_FOR_DRIVER_SECOND =
    'ride_accept_decline_duration_for_driver_in_second';
const MIN_AMOUNT_TO_ADD = 'min_amount_to_add';
const MAX_AMOUNT_TO_ADD = 'max_amount_to_add';
const APPLY_ADDITIONAL_FEE = 'apply_additional_fee';

//chat
List<String> rtlLanguage = ['ar', 'ur'];

enum MessageType {
  TEXT,
  IMAGE,
  VIDEO,
  AUDIO,
}

extension MessageExtension on MessageType {
  String? get name {
    switch (this) {
      case MessageType.TEXT:
        return 'TEXT';
      case MessageType.IMAGE:
        return 'IMAGE';
      case MessageType.VIDEO:
        return 'VIDEO';
      case MessageType.AUDIO:
        return 'AUDIO';
      default:
        return null;
    }
  }
}

String printAmount(String amount) {
  return appStore.currencyPosition == LEFT
      ? '${appStore.currencyCode} $amount'
      : '$amount ${appStore.currencyCode}';
}

const PDF_NAME = 'Mighty Taxi  Private Limited';
const PDF_ADDRESS = 'Sarah Street 9, Beijing, Ahmedabad';
const PDF_CONTACT_NUMBER = '+91 8888888888';

var errorSomethingWentWrong = 'Something Went Wrong';
const mRazorDescription = 'Mighty Rider';
const mStripeIdentifier = 'IN';

const walk_title1 = "Aceitar Pedidos de Corridas";
const walk_desc1 = "Obtenha Corridas de\npassageiros mais próximos";
const walk_title2 = "Aceite a Corrida";
const walk_desc2 =
    "Aceita a solicitação de corrida e leva\nSeu passageiro para o destino";
const walk_title3 = "Destino Final";
const walk_desc3 = "Entregue seu Passageiro no Destino Final";

const PER_PAGE = 50;
