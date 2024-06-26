import 'dart:io';
import 'dart:math';

import 'package:device_sim/device_sim.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../simulator/fitted_area.dart';
import '../frame/frame.dart';
import '../simulator/with_media_query_and_direction.dart';
import '../screen/screen.dart';
import '../simulator/toolbar.dart';

/// Device simulator that approximates the look and behavior of different devices.
/// Add a [DeviceSim] around your app and set [useInheritedMediaQuery] of your [MaterialApp] to true.
class DeviceSim extends StatefulWidget {
  /// Creates a new [DeviceSim].
  const DeviceSim(
      {Key? key,
      this.devices = const [iphone13, iphone13ProMax, ipad129Gen5],
      required this.builder,
      this.backgroundColor,
      this.isEnabled})
      : assert(devices.length > 0),
        super(key: key);

  /// List of devices to simulate. Must not be empty.
  final List<DeviceConfiguration> devices;

  /// Background color of simulator area.
  final Color? backgroundColor;

  /// Whether the simulator is active. Defaults to true if on web or desktop.
  final bool? isEnabled;

  /// The actual app.
  final WidgetBuilder builder;

  @override
  State<DeviceSim> createState() => _DeviceSimState();
}

class _DeviceSimState extends State<DeviceSim> {
  late DeviceConfiguration currentDevice;
  var isKeyboardVisible = false;
  var isUnsafeAreasVisible = false;
  var deviceEnabled = true;
  var orientation = Orientation.portrait;
  var zoom = 1.0;
  var zoomCorrection = 1.0;

  @override
  void initState() {
    super.initState();
    currentDevice = widget.devices.first;
    _updateTargetPlatform();
  }

  void _updateTargetPlatform() {
    if (_isEnabled() && deviceEnabled) {
      debugDefaultTargetPlatformOverride =
          currentDevice.screenConfiguration.targetPlatform;
    }
  }

  bool _isEnabled() {
    // important: check for kIsWeb first because Platform can't be accessed on web
    return widget.isEnabled ??
        kDebugMode && (kIsWeb || Platform.isMacOS || Platform.isWindows);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isEnabled()) {
      return widget.builder(context);
    }
    return WithMediaQueryAndDirection(
      child: Container(
        color: widget.backgroundColor ?? const Color(0xffeeeeee),
        child: Column(
          children: [
            if (deviceEnabled)
              Expanded(
                child: LayoutBuilder(builder: (context, layout) {
                  final screenSize = currentDevice.sizeFor(orientation);
                  final diagonalInInch =
                      currentDevice.standardRectangleDiagonalInInch;

                  final availableWidth = layout.maxWidth;
                  final availableHeight = layout.maxHeight;

                  final aspectRatio = screenSize.width / screenSize.height;
                  var widthToUse = availableWidth;
                  var heightToUse = widthToUse * (1 / aspectRatio);
                  if (heightToUse > availableHeight) {
                    heightToUse = availableHeight;
                    widthToUse = heightToUse * aspectRatio;
                  }

                  var deviceArea = (aspectRatio / (1 + pow(aspectRatio, 2))) *
                      pow(diagonalInInch, 2);

                  var pixelsPerInch = 96;

                  var virtualArea = (widthToUse / pixelsPerInch) *
                      (heightToUse / pixelsPerInch);

                  var newZoom = virtualArea / deviceArea;

                  if (newZoom != zoom) {
                    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                      setState(() {
                        zoom = newZoom;
                      });
                    });
                  }

                  return FittedArea(
                    sizeToUse: Size(widthToUse, heightToUse),
                    screenSize: screenSize,
                    child: Frame(
                        frameConfiguration: currentDevice.frameConfiguration,
                        child: Screen(
                            configuration: currentDevice.screenConfiguration,
                            isKeyboardVisible: isKeyboardVisible,
                            unsafeAreaColor: isUnsafeAreasVisible
                                ? Colors.yellow.withOpacity(0.5)
                                : null,
                            child: Builder(builder: (context) {
                              return widget.builder(context);
                            }))),
                  );
                }),
              ),
            if (!deviceEnabled)
              Expanded(
                child: LayoutBuilder(builder: (context, layout) {
                  return MediaQuery(
                      data:
                          MediaQuery.of(context).copyWith(size: layout.biggest),
                      child: Builder(builder: (context) {
                        return widget.builder(context);
                      }));
                }),
              ),
            Toolbar(
                isOn: deviceEnabled,
                selectedDeviceConfiguration: currentDevice,
                selectedOrientation: orientation,
                isKeyboardVisible: isKeyboardVisible,
                isUnsafeAreasVisible: isUnsafeAreasVisible,
                onCalibrateZoom: () {
                  setState(() {
                    zoomCorrection = 1 / zoom;
                  });
                },
                zoom: zoom * zoomCorrection,
                onSwitchOnOff: () {
                  setState(() {
                    deviceEnabled = !deviceEnabled;
                    _updateTargetPlatform();
                  });
                },
                onSwitchDevice: () {
                  setState(() {
                    currentDevice = widget.devices[
                        (widget.devices.indexOf(currentDevice) + 1) %
                            widget.devices.length];
                    _updateTargetPlatform();
                  });
                },
                onSwitchKeyboard: () {
                  setState(() {
                    isKeyboardVisible = !isKeyboardVisible;
                  });
                },
                onSwitchOrientation: () {
                  setState(() {
                    if (orientation == Orientation.portrait) {
                      orientation = Orientation.landscape;
                    } else {
                      orientation = Orientation.portrait;
                    }
                  });
                },
                onSwitchUnsafeAreaVisibility: () {
                  setState(() {
                    isUnsafeAreasVisible = !isUnsafeAreasVisible;
                  });
                })
          ],
        ),
      ),
    );
  }
}
