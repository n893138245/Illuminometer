//
//  ViewController.swift
//  lightLuxFlutter
//
//  Created by Sansi Mac on 2024/5/21.
//

import UIKit
import Foundation
import AVKit

/// 可以切换前后置摄像头，独立。
class SwitchCameraViewController: UIViewController, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    // 照度计功能
    var luminosityReading : Double = 0.0
    var cameraAccess = false
    public var session : AVCaptureSession!
    var configureAVCaptureSessionQueue = DispatchQueue(label: "ConfigureAVCaptureSessionQueue")
    // 添加属性来管理当前的摄像头
    var currentCameraPosition: AVCaptureDevice.Position = .back
    var currentInput: AVCaptureDeviceInput?
    // 数据
    var gridAry = [
        NSLocalizedString("第1次", comment: ""),
        NSLocalizedString("第2次", comment: ""),
        NSLocalizedString("差值", comment: ""),
        NSLocalizedString("变化率", comment: ""),
        "-",
        "-",
        "-",
        "-"
    ]
    var recordValueBtnClickCount = 1
    let defaults = UserDefaults.standard // 用于存取前后置摄像头的状态：默认false为“后置摄像头”，true为“前置摄像头”
    
    override func viewDidLoad() {
        super.viewDidLoad()
        illuminometer()
        createUI()
        getValue()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        checkCameraIsOn() // 为何在此处调用函数：因在viewDidLoad界面未加载完毕，无法调用弹窗功能。必须得在界面加载完毕后，才能调用窗口。
    }
    
    // MARK: - UI
    func createUI() {
        view.addSubview(switchCameraBtn)
        view.addSubview(moreBtn)
        view.addSubview(logoImg)
        view.addSubview(valueLbl)
        view.addSubview(valueStateLbl)
        view.addSubview(collectionView)
        view.addSubview(recordValueBtn)
//        view.addSubview(debugBtn)
    }
    
    lazy var switchCameraBtn: UIButton = {
        let view = UIButton(type: .custom)
        view.frame = CGRect.init(x: 0, y: kStatusBarH, width: 44, height: 44)
        view.setImage(UIImage(named: "backCamera"), for: .normal)
        view.imageView?.contentMode = .scaleAspectFit
        let imageSize: CGFloat = 24
        let imageInset = (44 - imageSize) / 2
        view.imageEdgeInsets = UIEdgeInsets(top: imageInset, left: imageInset, bottom: imageInset, right: imageInset)
        view.addTarget(self, action: #selector(switchCameraBtnClick), for: .touchUpInside)
        return view
    }()
    
    lazy var moreBtn: UIButton = {
        let view = UIButton(type: .custom)
        view.frame = CGRect.init(x: kScreenWidth - 44, y: kStatusBarH, width: 44, height: 44)
        view.setImage(UIImage(named: "info"), for: .normal)
        view.imageView?.contentMode = .scaleAspectFit
        let imageSize: CGFloat = 24
        let imageInset = (44 - imageSize) / 2
        view.imageEdgeInsets = UIEdgeInsets(top: imageInset, left: imageInset, bottom: imageInset, right: imageInset)
        view.addTarget(self, action: #selector(moreBtnClick), for: .touchUpInside)
        return view
    }()
    
    lazy var logoImg: UIImageView = {
        let view = UIImageView.init()
        let image = UIImage(named: "logo_sansi")
        view.image = image
        view.frame = CGRect.init(x: (kScreenWidth - 96) / 2, y: moreBtn.frame.origin.y + moreBtn.frame.height + 40, width: 96, height: 30)
        return view
    }()
    
    lazy var valueLbl: UILabel = {
        let view = UILabel.init()
        view.frame = CGRect.init(x: 0, y: logoImg.frame.origin.y + logoImg.frame.height + 86, width: kScreenWidth, height: 222)
        view.text = "Unknown"
        view.font = UIFont(name: "PingFangSC-UltraLight", size: 400)
        view.textColor = UIColor(red: 0/255, green: 0/255, blue: 0/255, alpha: 204/255)
        view.textAlignment = .center
        // 字体大小适应变化一行需要
        view.adjustsFontSizeToFitWidth = true
        view.minimumScaleFactor = 0.1
        view.numberOfLines = 1
        return view
    }()
    
    lazy var valueStateLbl: UILabel = {
        let view = UILabel.init()
        view.frame = CGRect.init(x: 0, y: valueLbl.frame.origin.y + valueLbl.frame.height + 10, width: kScreenWidth, height: 24)
        view.textAlignment = .center
        view.font = UIFont.systemFont(ofSize: 17)
        view.textColor = UIColor(red: 0/255, green: 0/255, blue: 0/255, alpha: 165/255)
        view.text = "Unknown"
        return view
    }()
    
    lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: kScreenWidth/4, height: kScreenWidth/4)
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        collectionView = UICollectionView(frame: CGRect.init(x: 0, y: CGRectGetMaxY(valueStateLbl.frame)+((kScreenHeight-CGRectGetMaxY(valueStateLbl.frame)-54-74)/3), width: kScreenWidth, height: 54), collectionViewLayout: layout)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(UINib.init(nibName: "GridCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "GridCollectionViewCell")
        collectionView.backgroundColor = .clear
        return collectionView
    }()
    
    lazy var recordValueBtn: CircularButton = {
        let view = CircularButton(frame: CGRect(x: (kScreenWidth - 74) / 2, y: CGRectGetMaxY(collectionView.frame)+((kScreenHeight-CGRectGetMaxY(valueStateLbl.frame)-54-74)/3), width: 74, height: 74))
        view.addTarget(self, action: #selector(recordValueBtnClick), for: .touchUpInside)
        return view
    }()
    
    lazy var debugBtn: UIButton = {
        let view = UIButton.init(type: .custom)
        view.frame = CGRect(x: moreBtn.frame.origin.x, y: CGRectGetMaxY(moreBtn.frame), width: moreBtn.frame.size.width, height: moreBtn.frame.size.height)
        view.setTitle(NSLocalizedString("调试", comment: ""), for: .normal)
        view.backgroundColor = .red
        view.tag = 1
        view.addTarget(self, action: #selector(debugBtnClick), for: .touchUpInside)
        return view
    }()
    
    // MARK: -事件功能
    @objc func switchCameraBtnClick() {
        let alert = UIAlertController(title: NSLocalizedString("提示", comment: ""), message: NSLocalizedString("选择摄像头", comment: ""), preferredStyle: .alert)
        let frontCamera = UIAlertAction(title: NSLocalizedString("前置摄像头", comment: ""), style: .default) { [self] action in
            switchCamera(currentCameraPosition: .front)
            switchCameraBtn.setImage(UIImage(named: "frontCamera"), for: .normal)
            saveValue()
        }
        let backCamera = UIAlertAction(title: NSLocalizedString("后置摄像头", comment: ""), style: .default) { [self] action in
            switchCamera(currentCameraPosition: .back)
            switchCameraBtn.setImage(UIImage(named: "backCamera"), for: .normal)
            saveValue()
        }
        let cancel = UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .default, handler: nil)
        alert.addAction(frontCamera)
        alert.addAction(backCamera)
        alert.addAction(cancel)
        present(alert, animated: true, completion: nil)
    }
    
    @objc func moreBtnClick() {
        let alert = UIAlertController(title: NSLocalizedString("提示", comment: ""), message: NSLocalizedString("由于不同手机的传感器和获取方法不同，在同一环境下，不同手机可能会显示不同的照度值。本应用无法替代照度计测量仪器，显示数值仅供参考。\n\nICP备案号：沪ICP备16020589号-11A", comment: ""), preferredStyle: .alert)
        let cancel = UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .default, handler:nil)
        let confirm = UIAlertAction(title: NSLocalizedString("查询", comment: ""), style: .default) { action in
            let url = URL.init(string: "https://beian.miit.gov.cn/")
            UIApplication.shared.open(url!)
        }
        alert.addAction(cancel)
        alert.addAction(confirm)
        present(alert, animated: true, completion: nil)
    }
    
    @objc func recordValueBtnClick() {
        let newValue: Int = Int(luminosityReading)
        if (recordValueBtnClickCount == 1) {
            gridAry[4] = String(newValue)
            recordValueBtnClickCount += 1
        } else if (recordValueBtnClickCount == 2) {
            gridAry[5] = String(newValue)
            recordValueBtnClickCount += 1
            let differenceValue = Int(gridAry[5])! -  Int(gridAry[4])!
            gridAry[6] = String(differenceValue)
            let rateOfChange = calculatePercentage(part: Double(gridAry[6])!, total: Double(gridAry[4])!)
            gridAry[7] = String(rateOfChange)
        } else {
            gridAry[4] = "-"
            gridAry[5] = "-"
            gridAry[6] = "-"
            gridAry[7] = "-"
            recordValueBtnClickCount = 1
        }
        collectionView.reloadData()
    }
    
    @objc func debugBtnClick() { // 调试按钮
        /*
        // 用于调试：当前用于上架app store时，截图预览
         print("debugBtnClick - tag: ", sender.tag)
         sender.tag = sender.tag + 1
         
         let newValue: Int = Int(1808)
         valueLbl.text = String(newValue)
         valueStateLbl.text = getEquivalent(luxValue: newValue)
         let gridAry4 = 743
         updateBackgroundColor(luxValue: CGFloat(gridAry4))
         gridAry[4] = String(gridAry4)
         gridAry[5] = String(1852)
         gridAry[6] = String(Int(gridAry[5])!-Int(gridAry[4])!)
         gridAry[7] = String(calculatePercentage(part: Double(gridAry[6])!, total: Double(gridAry[4])!))
         collectionView.reloadData()
         */
    }
    
    // MARK: -功能逻辑
    func getEquivalent(luxValue: Int) -> String {
        if (luxValue >= 32000) {
            return NSLocalizedString("阳光直射", comment: "")
        } else if (luxValue >= 10000) {
          return "全日光";
        } else if (luxValue >= 1000) {
            return NSLocalizedString("阴天", comment: "")
        } else if (luxValue >= 400) {
            return NSLocalizedString("晴天日出或日落", comment: "")
        } else if (luxValue >= 150) {
            return NSLocalizedString("办公室照明", comment: "")
        } else if (luxValue >= 100) {
            return NSLocalizedString("阴天非常暗", comment: "")
        } else if (luxValue >= 80) {
            return NSLocalizedString("公共走廊", comment: "")
        } else if (luxValue >= 50) {
            return NSLocalizedString("家庭客厅灯", comment: "")
        } else if (luxValue >= 10) {
            return NSLocalizedString("晴朗夜晚的满月", comment: "")
        } else {
            return NSLocalizedString("没有月亮的昏暗夜空", comment: "")
        }
    }
    
    // 处理：除法计算中的 NaN（不是一个数字）、inf（无穷大）、 -inf（负无穷大）
    func calculatePercentage(part: Double, total: Double) -> String {
        guard total != 0 else {
            return "N/A"
        }
        let percentage = (part / total) * 100
        // 检查计算结果是否为 NaN 或无穷大
        if percentage.isNaN || percentage.isInfinite {
            return "N/A"
        } else {
            return String(format: "%.2f%%", percentage)
        }
    }
    
    // 根据lux值变化，决定背景色的深度不同，颜色为橙色
    func updateBackgroundColor(luxValue: CGFloat) {
        // 将勒克斯值规范化到 0 到 1000 之间（根据实际光度值范围调整）
        let normalizedValue = max(0.0, min(1000.0, luxValue))
        // 设置最小和最大饱和度值
        let minSaturation: CGFloat = 0.2
        let maxSaturation: CGFloat = 1.0
        // 计算颜色饱和度（从 minSaturation 到 maxSaturation 之间）
        // 饱和度值越高，颜色越深
        let saturation = minSaturation + (normalizedValue / 1000.0) * (maxSaturation - minSaturation)
        // 使用 HSB 模型创建橙色的不同饱和度
        let baseHue: CGFloat = 30.0 / 360.0  // 橙色的色调在 HSB 模型中大约为30°
        let backgroundColor = UIColor(hue: baseHue, saturation: saturation, brightness: 1.0, alpha: 1.0)
        // 设置背景色
        self.view.backgroundColor = backgroundColor
    }
    
    // 切换摄像头
    func switchCamera(currentCameraPosition: AVCaptureDevice.Position) {
        guard let session = session else { return }
        session.beginConfiguration()
        // 获取当前的输入设备
        guard let currentInput = currentInput else { return }
        // 移除当前输入设备
        session.removeInput(currentInput)
        // 获取新的摄像头设备
        //        let newCameraPosition: AVCaptureDevice.Position = currentCameraPosition == .back ? .front : .back
        var newCameraPosition: AVCaptureDevice.Position = currentCameraPosition
        if (currentCameraPosition == .back) {
            newCameraPosition = .back
        } else {
            newCameraPosition = .front
        }
        guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newCameraPosition) else {
            print("Error: No camera found for the desired position.")
            session.commitConfiguration()
            return
        }
        // 创建新的输入设
        do {
            let newInput = try AVCaptureDeviceInput(device: newCamera)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                self.currentInput = newInput
                self.currentCameraPosition = newCameraPosition
            } else {
                // 如果无法添加新的输入设备，将旧的输入设备重新添加回来
                session.addInput(currentInput)
            }
        } catch {
            print("Error: Unable to initialize new camera input: \(error)")
            session.addInput(currentInput)
        }
        session.commitConfiguration()
    }
    
    func saveValue() {
        if (currentCameraPosition == .back) {
            defaults.set(false, forKey: "cameraStatus") // 存值
        } else {
            defaults.set(true, forKey: "cameraStatus") // 存值
        }
    }
    
    func getValue() {
        if (defaults.bool(forKey: "cameraStatus") == false) { // 取值
            switchCameraBtn.setImage(UIImage(named: "backCamera"), for: .normal)
//            currentCameraPosition = .back
        } else {
            switchCameraBtn.setImage(UIImage(named: "frontCamera"), for: .normal)
//            currentCameraPosition = .front
        }
    }
    
    func checkCameraIsOn() { // 检查摄像头是否开启?
        view.backgroundColor = .white // 目的：避免未开启摄像头时，界面为黑暗状态
        let cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
//        if (cameraAuthorizationStatus == .denied || cameraAuthorizationStatus == .notDetermined || cameraAuthorizationStatus == .restricted) { // 用户否决、拒绝、尚未作出选择
        if (cameraAuthorizationStatus == .denied || cameraAuthorizationStatus == .restricted) { // 用户否决、尚未作出选择 // 取消“拒绝”。避免首次进入app时，即使“同意”使用摄像头了，仍然会跳出弹窗问题。
            let alert = UIAlertController(title: NSLocalizedString("提示", comment: ""), message: NSLocalizedString("摄像头未开启，无法获取照度值，请您在设置中开启它", comment: ""), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("设置", comment: ""), style: .default, handler: { _ in
                guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                    return
                }
                if UIApplication.shared.canOpenURL(settingsUrl) {
                    UIApplication.shared.open(settingsUrl, completionHandler: { (success) in
                        print("Settings opened: \(success)")
                    })
                }
            }))
            alert.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }
    
    // MARK: -其它：collectionView
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 8
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GridCollectionViewCell", for: indexPath) as! GridCollectionViewCell
        if (indexPath.item == 0 || indexPath.item == 1 || indexPath.item == 2 || indexPath.item == 3) {
            cell.titleLbl.font = UIFont(name: "PingFang SC", size: 14)
            cell.titleLbl.textColor = UIColor(red: 0/255, green: 0/255, blue: 0/255, alpha: 115/255)
        } else {
            cell.titleLbl.font = UIFont(name: "Roboto", size: 17)
            cell.titleLbl.textColor = UIColor(red: 0/255, green: 0/255, blue: 0/255, alpha: 204/255)
        }
        cell.titleLbl.text = gridAry[indexPath.item]
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: kScreenWidth/4, height: 54/2)
    }

    // MARK: - 照度计功能
    // 照度计功能从flutter集合
    func illuminometer() {
        // 照度计功能
        configureAVCaptureSessionQueue.async {
           self.authorizeCapture() // this needs to be awaited
        }
    }
    
    // 获取Lux值
    func sendGetLuxValue(value: Double) {
//        let channel: FlutterMethodChannel = FlutterMethodChannel(name: "plugin_apple", binaryMessenger: messenger!)
        let newValue: Int = Int(value)
//        channel.invokeMethod("invoke/lux", arguments: newValue);
//        print("值：", newValue)
        valueLbl.text = String(newValue)
        valueStateLbl.text = getEquivalent(luxValue: newValue)
        updateBackgroundColor(luxValue: CGFloat(newValue))
    }

    // MARK: - 照度计功能
    /*
     Determine authroization status and request authorization if necessary.
     */
    func authorizeCapture()  {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: // The user has previously granted access to the camera.
            DispatchQueue.main.async {
                self.cameraAccess = true
            }
            beginCapture()
        case .notDetermined: // The user has not yet been asked for camera access.
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.cameraAccess = true
                    }
                    self.beginCapture()
                }
            }

        default:
            return
        }
    }

    /*
     Find best device and add it as input, establish output and set its sample buffer delegate
     in order to call captureOutput and calculate brightness in lux.
     */
    func beginCapture() {

        session = AVCaptureSession()
        session.beginConfiguration()

//        guard let videoDevice = AVCaptureDevice.default(for: .video) else { return }
        
        /**/
        let videoDevice: AVCaptureDevice;
        if (defaults.bool(forKey: "cameraStatus") == false) { // 取值判断
            videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)!
        } else {
            videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)!
        }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
                self.currentInput = videoInput
                self.currentCameraPosition = videoDevice.position // 问题在这，无法实现“前后摄像头”切换；
            }
        } catch {
            print("Camera selection failed: \(error)")
            return
        }

        let videoOutput = AVCaptureVideoDataOutput()
        guard session.canAddOutput(videoOutput) else {
            print("Error creating video output")
            return
        }
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "CaptureOutputQueue"))
        session.addOutput(videoOutput)

        session.sessionPreset = .medium
        session.commitConfiguration()
        session.startRunning()
    }

    // Calculate brightness in lux
    // From: https://stackoverflow.com/questions/41921326/how-to-get-light-value-from-avfoundation/46842115#46842115
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        let rawMetadata = CMCopyDictionaryOfAttachments(allocator: nil, target: sampleBuffer, attachmentMode: CMAttachmentMode(kCMAttachmentMode_ShouldPropagate))
        let metadata = CFDictionaryCreateMutableCopy(nil, 0, rawMetadata) as NSMutableDictionary
        let exifData = metadata.value(forKey: "{Exif}") as? NSMutableDictionary

        let FNumber : Double = exifData?["FNumber"] as! Double
        let ExposureTime : Double = exifData?["ExposureTime"] as! Double
        let ISOSpeedRatingsArray = exifData!["ISOSpeedRatings"] as? NSArray
        let ISOSpeedRatings : Double = ISOSpeedRatingsArray![0] as! Double
        let CalibrationConstant : Double = 50

        let luminosity : Double = (CalibrationConstant * FNumber * FNumber ) / ( ExposureTime * ISOSpeedRatings )
        DispatchQueue.main.async {
            self.luminosityReading = luminosity
//            print("luminosity:",luminosity)
//            let value = String(format: "%.0f  Lux", luminosity)
//            self.titleLbl.text = value
            // 将数据发送出去
            self.sendGetLuxValue(value: luminosity)
        }
    }
}
