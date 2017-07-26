## 介绍
项目是基于AVFoundation使用AVAssetWriter进行视频录制,并且支持断点录制。

主要特性：

* 可自定义UI
* 支持断点录制
* 可自定义视频录入的参数（视频宽高、视频压缩）
* 基于swift4，在swift3中需要修改几个系统的类名和函数名称

主要包括三个类：

* CaptureSessionCoordinator：相机调度相关的类。
* AssetWriterCoordinator：视频写入相关的类。
* CaptureSeesionUI：相机界面，可自定义。

```
import UIKit
import MediaPlayer
import AVKit

class ViewController: UIViewController {
    
    var captureCoordinator: CaptureSessionCoordinator!
    var writerCoordinator: AssetWriterCoordinator!
    var url: URL!
    var timer: CADisplayLink!
    
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet weak var progressView: UIProgressView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /// 相机调度类创建有可能失败的原因：
        /// 1、没有开启摄像头、麦克风权限
        /// 2、输入设备（摄像头、麦克风）损害
        /// 3、无法添加输出（AVCaptureVideoDataOutput）
        captureCoordinator = try! CaptureSessionCoordinator()
        
        ///将预览视频添加到view上
        view.insertSubview(captureCoordinator.previewView, at: 0)
        captureCoordinator.previewView.fillToSuperview()
        
        /// 准备开启AVCaptureSession
        try? captureCoordinator.prepareSession()
        
        /// 创建视频写入类
        url = NSURL.fileURL(withPath: "\(NSTemporaryDirectory())tmp\(arc4random()).mp4")
        writerCoordinator = try! AssetWriterCoordinator(fileUrl: url)
        /// 添加视频写入类
        captureCoordinator.movieWriter = writerCoordinator
    }
    
    @IBAction func recordAction(_ sender: UIButton) {
        
        /// 开始写入视频
        if writerCoordinator.status == .unknown {
            writerCoordinator.startWriting()
            timer = CADisplayLink(target: self, selector: #selector(updateProgress))
            timer.add(to: RunLoop.main, forMode: .commonModes)
        }/// 暂停写入视频
        else if writerCoordinator.status == .writing {
            timer.isPaused = true
            writerCoordinator.pauseWriting()
        }/// 恢复写入视频
        else if writerCoordinator.status == .paused {
            timer.isPaused = false
            writerCoordinator.resumeWriting()
        }
        
        sender.isSelected = !sender.isSelected
    }
    
    @IBAction func closeAction(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    /// 切换摄像头
    @IBAction func swapAction(_ sender: Any) {
        
        try? captureCoordinator.swapCameras()
        if captureCoordinator.capmerPosition == .front {
            flashButton.isSelected = false
        }
    }
    
    /// 开启闪光灯
    @IBAction func flashAction(_ sender: UIButton) {
        let success = captureCoordinator.toggleFlash()
        if success {
            sender.isSelected = !sender.isSelected
        }
    }
    
    /// 更新录制的进度条
    @objc func updateProgress() {
        let proportion = writerCoordinator.duration / 15
        progressView.progress = Float(proportion)
        if proportion >= 1 {
            timer.invalidate()
            writerCoordinator.finishWritingWithCompletionHandler {
                let playerVC = MPMoviePlayerViewController(contentURL: self.url)!
                playerVC.moviePlayer.prepareToPlay()
                playerVC.moviePlayer.play()
                self.present(playerVC, animated: true, completion: nil)
            }
        }
    }
    
}

```

## CaptureSessionCoordinator

```
/// 预览视图属性
public let previewView = CaptureSessionPreviewView(frame: .zero)

/// 会话对象    
public let session = AVCaptureSession()
    
/// 当前摄像头的位置        
public var capmerPosition: AVCaptureDevice.Position? {
    return videoDeviceInput?.device.position
}

/// 视频写入处理的队列    
public var captureQueue: DispatchQueue = DispatchQueue(label: "CaptureSessionCoordinator")
    
/// 视频写入类    
public var movieWriter: AssetWriterCoordinator?

/// 准备开启会话
func prepareSession() throws {
    ...
}
    
/// 开启闪光灯 
public func toggleFlash() -> Bool {
    ...
}

/// 切换摄像头
public func swapCameras() throws {
    ...
}

```

## AssetWriterCoordinator

```
/// 视频写入的状态
public var status: WriterCoordinatorStatus 

/// 视频写入的时间，不包括暂停时间    
public var duration: Double 

/// 开始写入,返回值是否成功开始
public func startWriting() -> Bool { }
    
/// 暂停写入    
public func pauseWriting() { }
    
/// 恢复写入
public func resumeWriting() { }
	
/// 取消写入
public func cancelWriting() { }
    
/// 结束写入
public func finishWriting() { }
    
public func finishWritingWithCompletionHandler(_ handler: @escaping ()->()) { }
    
/// 保存到相册
public func saveToAlbumWithCompletionHandler(_ handler:((Bool,Error?) -> ())? = nil) { }

```

## 预览图

![效果图](./img_0103.png)


## 参考资料

* [WCLRecordVideo](https://github.com/imwcl/WCLRecordVideo) (盗用图片和UI布局)
* [GPUImage](https://github.com/BradLarson/GPUImage)