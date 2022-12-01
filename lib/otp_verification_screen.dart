import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:phone_authentication_demo/home_screen.dart';
import 'package:pinput/pinput.dart';
import 'package:sms_autofill/sms_autofill.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumberControllerValueText;
  const OTPVerificationScreen({
    Key? key,
    required this.phoneNumberControllerValueText,
  }) : super(key: key);

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen>
    with CodeAutoFill {
  String tempVerificationId = '';

  final _formKey = GlobalKey<FormState>();
  final TextEditingController otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    log('phoneNumberControllerValueText: ${widget.phoneNumberControllerValueText}');
    listenAppSignature();
    listenForCodeMethod();
    SmsAutoFill().code.asBroadcastStream().listen((event) {
      log('Full OTP asBroadcastStream : ${event.toString()}');
    });
    verifyPhoneNumber();
  }

  Future<String> listenAppSignature() async {
    String getAppSignature = await SmsAutoFill().getAppSignature;
    log('appSignature: $getAppSignature');
    return Future.value(getAppSignature);
  }

  void listenForCodeMethod() {
    SmsAutoFill().listenForCode;
  }

  @override
  void dispose() {
    otpController.dispose();
    _formKey.currentState?.dispose();
    SmsAutoFill().unregisterListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: FocusManager().primaryFocus?.unfocus,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text('OTP Verify'),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Pinput(
                    controller: otpController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter OTP';
                      } else if (value.length != 6) {
                        return 'Please enter valid 6 digit OTP';
                      } else {
                        return null;
                      }
                    },
                    keyboardType: TextInputType.number,
                    length: 6,
                    androidSmsAutofillMethod:
                        AndroidSmsAutofillMethod.smsRetrieverApi,
                    pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
                    showCursor: true,
                    onCompleted: (pin) => verify(),
                    listenForMultipleSmsOnAndroid: true,
                    pinAnimationType: PinAnimationType.rotation,
                    closeKeyboardWhenCompleted: true,
                    animationDuration: const Duration(seconds: 1),
                  ),
                  const SizedBox(
                    height: 100,
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        verify();
                      }
                    },
                    child: const Text('Submit'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void verify() async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: tempVerificationId,
          smsCode: otpController.value.text);
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      if (userCredential.user != null) {
        log('verify - User logged in.');

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) {
                return const HomeScreen();
              },
            ),
            (Route<dynamic> route) => false,
          );
        }
      }
    } catch (e) {
      FocusManager.instance.primaryFocus?.unfocus();
      log('verify - Invalid OTP.');
      log('e.toString: ${e.toString()}');
    }
  }

  verifyPhoneNumber() async {
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: widget.phoneNumberControllerValueText,
      verificationCompleted: (PhoneAuthCredential credential) async {
        UserCredential userCredential =
            await FirebaseAuth.instance.signInWithCredential(credential);
        if (userCredential.user != null) {
          log('verifyPhoneNumber - User logged in.');

          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) {
                  return const HomeScreen();
                },
              ),
              (Route<dynamic> route) => false,
            );
          }
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        log('e.toString: ${e.message.toString()}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.message.toString(),
            ),
          ),
        );
        if (e.code == 'invalid-phone-number') {
          log('The provided phone number is not valid.');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'The provided phone number is not valid.',
              ),
            ),
          );
        }
      },
      codeSent: (String verificationId, int? resendToken) async {
        tempVerificationId = verificationId;
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        tempVerificationId = verificationId;
      },
      timeout: const Duration(seconds: 60),
    );
  }

  @override
  void codeUpdated() {
    log('codeUpdated() : ${code.toString()}');
  }
}
