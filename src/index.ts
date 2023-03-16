import { NativeModules, Platform } from 'react-native';
const RNVoipCall = require('react-native-voip-call');

const isIOS = Platform.OS === 'ios';

const IncomingCall = isIOS ? RNVoipCall : NativeModules.IncomingCall;

export default IncomingCall;
