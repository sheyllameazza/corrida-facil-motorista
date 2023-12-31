import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:taxi_driver/screens/DriverDashboardScreen.dart';
import 'package:taxi_driver/utils/Constants.dart';
import 'package:taxi_driver/utils/Extensions/StringExtensions.dart';
import 'package:taxi_driver/utils/Images.dart';

import '../../main.dart';
import '../Services/AuthService.dart';
import '../components/OTPDialog.dart';
import '../model/UserDetailModel.dart';
import '../network/RestApis.dart';
import '../utils/Colors.dart';
import '../utils/Common.dart';
import '../utils/Extensions/AppButtonWidget.dart';
import '../utils/Extensions/app_common.dart';
import '../utils/Extensions/app_textfield.dart';
import 'DriverRegisterScreen.dart';
import 'ForgotPasswordScreen.dart';
import 'TermsConditionScreen.dart';
import 'VerifyDeliveryPersonScreen.dart';

class LoginScreen extends StatefulWidget {
  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late UserData _userModel;

  GlobalKey<FormState> formKey = GlobalKey<FormState>();

  AuthServices authService = AuthServices();
  GoogleAuthServices googleAuthService = GoogleAuthServices();

  TextEditingController emailController = TextEditingController();
  TextEditingController passController = TextEditingController();

  FocusNode emailFocus = FocusNode();
  FocusNode passFocus = FocusNode();

  bool mIsCheck = false;
  bool isAcceptedTc = false;
  String? privacyPolicy;
  String? termsCondition;

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    appSetting();
    if (sharedPref.getString(PLAYER_ID).validate().isEmpty) {
      await saveOneSignalPlayerId().then((value) {
        //
      });
    }
    mIsCheck = sharedPref.getBool(REMEMBER_ME) ?? false;
    if (mIsCheck) {
      emailController.text = sharedPref.getString(USER_EMAIL).validate();
      passController.text = sharedPref.getString(USER_PASSWORD).validate();
    }
  }

  Future<void> logIn() async {
    hideKeyboard(context);
    if (formKey.currentState!.validate()) {
      formKey.currentState!.save();
      if (isAcceptedTc) {
        appStore.setLoading(true);

        Map req = {
          'email': emailController.text.trim(),
          'password': passController.text.trim(),
          "player_id": sharedPref.getString(PLAYER_ID).validate(),
          'user_type': 'driver',
        };
        if (mIsCheck) {
          await sharedPref.setBool(REMEMBER_ME, mIsCheck);
          await sharedPref.setString(USER_EMAIL, emailController.text);
          await sharedPref.setString(USER_PASSWORD, passController.text);
        }
        await logInApi(req).then((value) async {
          _userModel = value.data!;
          await _auth.signInWithEmailAndPassword(email: emailController.text, password: passController.text).then((value) {
            sharedPref.setString(UID, value.user!.uid);
            updateProfileUid();
            if (sharedPref.getInt(IS_Verified_Driver) == 1) {
              launchScreen(context, DriverDashboardScreen(), isNewTask: true, pageRouteAnimation: PageRouteAnimation.Slide);
            } else {
              launchScreen(context, VerifyDeliveryPersonScreen(isShow: true), isNewTask: true, pageRouteAnimation: PageRouteAnimation.Slide);
            }
            appStore.isLoading = false;
          }).catchError((e) {
            if (e.toString().contains('user-not-found')) {
              authService.signUpWithEmailPassword(
                context,
                mobileNumber: _userModel.contactNumber,
                email: emailController.text,
                fName: _userModel.firstName,
                lName: _userModel.lastName,
                userName: _userModel.username,
                password: passController.text,
                userType: 'driver',
              );
            } else {
              if (sharedPref.getInt(IS_Verified_Driver) == 1) {
                launchScreen(context, DriverDashboardScreen(), isNewTask: true, pageRouteAnimation: PageRouteAnimation.Slide);
              } else {
                launchScreen(context, VerifyDeliveryPersonScreen(isShow: true), isNewTask: true, pageRouteAnimation: PageRouteAnimation.Slide);
              }
            }
            //toast(e.toString());
            log('${e.toString()}');
            log(e.toString());
          });
        }).catchError((error) {
          appStore.setLoading(false);

          toast(error.toString());
          log('${error.toString()}');
        });
      } else {
        toast(language.pleaseAcceptTermsOfServicePrivacyPolicy);
      }
    }
  }

  Future<void> appSetting() async {
    await getAppSettingApi().then((value) {
      if (value.privacyPolicyModel!.value != null) privacyPolicy = value.privacyPolicyModel!.value;
      if (value.termsCondition!.value != null) termsCondition = value.termsCondition!.value;
    }).catchError((error) {
      log(error.toString());
    });
  }

  void googleSignIn() async {
    hideKeyboard(context);
    appStore.setLoading(true);

    await googleAuthService.signInWithGoogle(context).then((value) async {
      appStore.setLoading(false);
    }).catchError((e) {
      appStore.setLoading(false);
      toast(e.toString());
      print(e.toString());
    });
  }

  appleLoginApi() async {
    hideKeyboard(context);
    appStore.setLoading(true);
    await appleLogIn().then((value) {
      appStore.setLoading(false);
    }).catchError((e) {
      appStore.setLoading(false);
      toast(e.toString());
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16),
                  Text(language.welcomeBack, style: boldTextStyle(size: 22)),
                  SizedBox(height: 8),
                  Text(language.signInYourAccount, style: primaryTextStyle()),
                  SizedBox(height: 32),
                  AppTextField(
                    controller: emailController,
                    nextFocus: passFocus,
                    autoFocus: false,
                    textFieldType: TextFieldType.EMAIL,
                    keyboardType: TextInputType.emailAddress,
                    errorThisFieldRequired: language.thisFieldRequired,
                    decoration: inputDecoration(context, label: language.email),
                  ),
                  SizedBox(height: 20),
                  AppTextField(
                    controller: passController,
                    focus: passFocus,
                    autoFocus: false,
                    textFieldType: TextFieldType.PASSWORD,
                    errorThisFieldRequired: language.thisFieldRequired,
                    decoration: inputDecoration(context, label: language.password),
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      SizedBox(
                        height: 18.0,
                        width: 18.0,
                        child: Checkbox(
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          activeColor: primaryColor,
                          value: mIsCheck,
                          shape: RoundedRectangleBorder(borderRadius: radius(2)),
                          onChanged: (v) async {
                            mIsCheck = v!;
                            if (!mIsCheck) {
                              sharedPref.remove(REMEMBER_ME);
                            }
                            setState(() {});
                          },
                        ),
                      ),
                      SizedBox(width: 8),
                      inkWellWidget(
                          onTap: () async {
                            mIsCheck = !mIsCheck;
                            setState(() {});
                          },
                          child: Text(language.rememberMe, style: primaryTextStyle(size: 14))),
                    ],
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      SizedBox(
                        height: 18,
                        width: 18,
                        child: Checkbox(
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          activeColor: primaryColor,
                          value: isAcceptedTc,
                          shape: RoundedRectangleBorder(borderRadius: radius(2)),
                          onChanged: (v) async {
                            isAcceptedTc = v!;
                            setState(() {});
                          },
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(children: [
                            TextSpan(text: '${language.iAgreeToThe} ', style: secondaryTextStyle()),
                            TextSpan(
                              text: language.termsConditions,
                              style: boldTextStyle(color: primaryColor, size: 14),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  if (termsCondition != null && termsCondition!.isNotEmpty) {
                                    launchScreen(context, TermsConditionScreen(title: language.termsConditions, subtitle: termsCondition), pageRouteAnimation: PageRouteAnimation.Slide);
                                  } else {
                                    toast(language.txtURLEmpty);
                                  }
                                },
                            ),
                            TextSpan(text: ' & ', style: secondaryTextStyle()),
                            TextSpan(
                              text: language.privacyPolicy,
                              style: boldTextStyle(color: primaryColor, size: 14),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  if (privacyPolicy != null && privacyPolicy!.isNotEmpty) {
                                    launchScreen(context, TermsConditionScreen(title: language.privacyPolicy, subtitle: privacyPolicy), pageRouteAnimation: PageRouteAnimation.Slide);
                                  } else {
                                    toast(language.txtURLEmpty);
                                  }
                                },
                            ),
                          ]),
                          textAlign: TextAlign.left,
                        ),
                      )
                    ],
                  ),
                  SizedBox(height: 20),
                  AppButtonWidget(
                    width: MediaQuery.of(context).size.width,
                    text: language.logIn,
                    onTap: () async {
                      logIn();
                    },
                  ),
                  SizedBox(height: 16),
                  Align(
                    alignment: Alignment.topRight,
                    child: inkWellWidget(
                      onTap: () {
                        hideKeyboard(context);
                        launchScreen(context, ForgotPasswordScreen(), pageRouteAnimation: PageRouteAnimation.SlideBottomTop);
                      },
                      child: Text(language.forgotPassword, style: boldTextStyle()),
                    ),
                  ),
                  SizedBox(height: 10),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(child: Divider(color: primaryColor.withOpacity(0.5))),
                        Padding(
                          padding: EdgeInsets.only(left: 16, right: 16),
                          child: Text(language.orLogInWith, style: primaryTextStyle()),
                        ),
                        Expanded(child: Divider(color: primaryColor.withOpacity(0.5))),
                      ],
                    ),
                  ),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      inkWellWidget(
                        onTap: () async {
                          googleSignIn();
                        },
                        child: socialWidget(image: ic_google),
                      ),
                      SizedBox(width: 12),
                      inkWellWidget(
                        onTap: () async {
                          showDialog(
                            context: context,
                            builder: (_) {
                              return AlertDialog(
                                contentPadding: EdgeInsets.all(16),
                                content: OTPDialog(),
                              );
                            },
                          );
                        },
                        child: socialWidget(image: ic_mobile),
                      ),
                      if(Platform.isIOS) SizedBox(width: 12),
                      if(Platform.isIOS) inkWellWidget(
                        onTap: () async {
                          appleLoginApi();
                        },
                        child: socialWidget(image: ic_apple),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Align(
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(language.donHaveAnAccount, style: primaryTextStyle()),
                        SizedBox(width: 8),
                        inkWellWidget(
                          onTap: () {
                            hideKeyboard(context);
                            launchScreen(context, DriverRegisterScreen(), pageRouteAnimation: PageRouteAnimation.SlideBottomTop);
                          },
                          child: Text(language.signUp, style: boldTextStyle(color: primaryColor)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Observer(
            builder: (context) {
              return Visibility(
                visible: appStore.isLoading,
                child: loaderWidgetLogIn(),
              );
            },
          ),
        ],
      ),
    );
  }
}
