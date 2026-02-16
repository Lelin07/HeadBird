import CoreBluetooth
import Foundation
import IOBluetooth

@MainActor
final class BluetoothMonitor: NSObject {
    var onAuthorizationChanged: ((CBManagerAuthorization) -> Void)?

    private var centralManager: CBCentralManager?
    private var didAttemptPermissionScan = false

    override init() {
        super.init()
        requestAuthorizationIfNeeded()
    }

    func requestAuthorizationIfNeeded() {
        guard centralManager == nil else { return }
        centralManager = CBCentralManager(
            delegate: self,
            queue: .main,
            options: [CBCentralManagerOptionShowPowerAlertKey: false]
        )
        onAuthorizationChanged?(CBCentralManager.authorization)
    }

    func connectedAirPods() -> [String] {
        requestAuthorizationIfNeeded()
        let devices = bluetoothDevices(selectorName: "connectedDevices") + bluetoothDevices(selectorName: "pairedDevices")

        let names = devices.compactMap { device -> String? in
            guard device.isConnected() else { return nil }
            let name = device.name ?? device.nameOrAddress ?? ""
            guard isAirPodsName(name) else { return nil }
            return name
        }

        return Array(Set(names)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func isAirPodsName(_ name: String) -> Bool {
        name.lowercased().contains("airpods")
    }

    private func bluetoothDevices(selectorName: String) -> [IOBluetoothDevice] {
        let selector = NSSelectorFromString(selectorName)
        let typeObject: AnyObject = IOBluetoothDevice.self

        guard typeObject.responds(to: selector),
              let unmanagedValue = typeObject.perform(selector) else {
            return []
        }

        let value = unmanagedValue.takeUnretainedValue()
        if let devices = value as? [IOBluetoothDevice] {
            return devices
        }
        if let devices = value as? [Any] {
            return devices.compactMap { $0 as? IOBluetoothDevice }
        }
        return []
    }

    private func requestPermissionScanIfNeeded(using central: CBCentralManager) {
        guard !didAttemptPermissionScan else { return }
        guard CBCentralManager.authorization == .notDetermined else { return }
        guard central.state == .poweredOn else { return }

        didAttemptPermissionScan = true
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak central] in
            central?.stopScan()
        }
    }
}

extension BluetoothMonitor: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        onAuthorizationChanged?(CBCentralManager.authorization)
        requestPermissionScanIfNeeded(using: central)
    }
}
