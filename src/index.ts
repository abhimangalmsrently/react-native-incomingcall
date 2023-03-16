import { NativeModules, Platform } from 'react-native';
const RNVoipCall = require('react-native-voip-call');

const isIOS = Platform.OS === 'ios';

const IncomingCall = isIOS
  ? { ...RNVoipCall, ...RNVoipCall.RNVoipPushKit }
  : NativeModules.IncomingCall;

export default IncomingCall;
