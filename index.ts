import { NativeModules, Platform } from 'react-native';
import RNVoipCall, { RNVoipPushKit } from 'react-native-voip-call';

const isIOS = Platform.OS === 'ios';

const IncomingCall = isIOS ? RNVoipCall : NativeModules.IncomingCall;
const IncomingCallPushKit = RNVoipPushKit;

export { IncomingCall, IncomingCallPushKit }