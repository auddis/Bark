//
//  SoundsViewController.swift
//  Bark
//
//  Created by huangfeng on 2020/9/14.
//  Copyright © 2020 Fin. All rights reserved.
//

import AVKit
import Material
import SVProgressHUD
import UIKit
import UniformTypeIdentifiers

import NSObject_Rx
import RxCocoa
import RxDataSources
import RxSwift

class SoundsViewController: BaseViewController<SoundsViewModel> {
    let closeButton: BKButton = {
        let closeButton = BKButton()
        closeButton.setImage(UIImage(named: "baseline_keyboard_arrow_down_black_24pt")?.withRenderingMode(.alwaysTemplate), for: .normal)
        closeButton.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        closeButton.hitTestSlop = UIEdgeInsets(top: -10, left: -10, bottom: -10, right: -10)
        closeButton.tintColor = BKColor.grey.darken4
        closeButton.accessibilityLabel = "close".localized
        return closeButton
    }()

    let tableView: UITableView = {
        let tableView = UITableView(frame: CGRect.zero, style: .insetGrouped)
        tableView.backgroundColor = BKColor.background.primary
        tableView.register(SoundCell.self, forCellReuseIdentifier: "\(SoundCell.self)")
        tableView.register(AddSoundCell.self, forCellReuseIdentifier: "\(AddSoundCell.self)")
        return tableView
    }()
    
    // 上传铃声文件事件序列
    let importSoundActionRelay = PublishRelay<URL>()
    // 当前正在播放的音频资源ID
    var currentSoundID: SystemSoundID = 0
    // 当前正在播放的音频文件ULRL
    var playingAudio: CFURL?

    override func makeUI() {
        self.title = "notificationSound".localized

        navigationItem.setRightBarButtonItem(item: UIBarButtonItem(customView: closeButton))

        self.view.addSubview(self.tableView)
        self.tableView.delegate = self
        self.tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        closeButton.rx.tap.subscribe(onNext: { [weak self] _ in
            self?.dismiss(animated: true, completion: nil)
        }).disposed(by: rx.disposeBag)
    }

    override func bindViewModel() {
        let output = viewModel.transform(
            input: SoundsViewModel.Input(
                soundSelected: self.tableView.rx.modelSelected(SoundItem.self).asDriver(),
                importSound: self.importSoundActionRelay.asDriver(onErrorDriveWith: .empty()),
                soundDeleted: self.tableView.rx.modelDeleted(SoundItem.self).asDriver()
            )
        )

        let dataSource = RxTableViewSectionedReloadDataSource<SectionModel<String, SoundItem>> { _, tableView, _, item -> UITableViewCell in
            switch item {
            case .sound(let model):
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "\(SoundCell.self)") as? SoundCell else {
                    return UITableViewCell()
                }
                cell.bindViewModel(model: model)
                return cell
            case .addSound:
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "\(AddSoundCell.self)") else {
                    return UITableViewCell()
                }
                return cell
            }
        } titleForHeaderInSection: { dataSource, section in
            return dataSource[section].model
        } canEditRowAtIndexPath: { dataSource, indexPath in
            guard indexPath.section == 0 else {
                return false
            }
            guard case SoundItem.sound = dataSource[indexPath.section].items[indexPath.row] else {
                return false
            }
            return true
        }

        output.audios
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: rx.disposeBag)

        output.copyNameAction.drive(onNext: { [unowned self] name in
            UIPasteboard.general.string = name.trimmingCharacters(in: .whitespacesAndNewlines)
            self.navigationController?.showSnackbar(text: "Copy".localized)
        }).disposed(by: rx.disposeBag)

        output.playAction.drive(onNext: { url in
            /// 先结束正在播放的音频
            AudioServicesDisposeSystemSoundID(self.currentSoundID)
            /// 如果重复点击了当前音频，结束播放
            if self.playingAudio == url {
                self.playingAudio = nil
                self.currentSoundID = 0
                return
            }
            self.playingAudio = url
            AudioServicesCreateSystemSoundID(url, &self.currentSoundID)
            AudioServicesPlaySystemSoundWithCompletion(self.currentSoundID) {
                /// 判断是否是当前播放的音频，防止逻辑错误
                if self.playingAudio == url {
                    AudioServicesDisposeSystemSoundID(self.currentSoundID)
                    self.playingAudio = nil
                    self.currentSoundID = 0
                }
            }
        }).disposed(by: rx.disposeBag)
        
        output.pickerFile.drive(onNext: { [unowned self] _ in
            self.pickerSoundFile()
        }).disposed(by: rx.disposeBag)
    }
}

extension SoundsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        guard section == 0 else {
            return 0
        }
        return "uploadSoundNoticeFullText".localized.count <= 30 ? 50 : 60
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let sectionTitle = tableView.dataSource?.tableView?(tableView, titleForHeaderInSection: section) ?? ""
        
        let view = UIView()
        
        let label = UILabel()
        label.text = sectionTitle.localized
        label.fontSize = 14
        label.textColor = BKColor.grey.darken3
        view.addSubview(label)
        label.snp.makeConstraints { make in
            make.left.equalTo(12)
            make.centerY.equalToSuperview()
        }
        
        return view
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard section == 0 else {
            return nil
        }
        let view = UIView()

        let fullText = "uploadSoundNoticeFullText".localized
        let highlightText = "uploadSoundNoticeHighlightText".localized
        let attrStr = NSMutableAttributedString(
            string: fullText,
            attributes: [
                NSAttributedString.Key.foregroundColor: BKColor.grey.darken3,
                NSAttributedString.Key.font: UIFont.preferredFont(ofSize: 14)
            ]
        )
        attrStr.setAttributes([
            NSAttributedString.Key.foregroundColor: BKColor.lightBlue.darken3,
            NSAttributedString.Key.font: UIFont.preferredFont(ofSize: 14)
        ], range: (fullText as NSString).range(of: highlightText))
        
        let label = UILabel()
        label.attributedText = attrStr
        label.numberOfLines = 0
        view.addSubview(label)
        label.snp.makeConstraints { make in
            make.left.equalTo(12)
            make.right.equalTo(-12)
            make.top.equalTo(12)
        }
        
        label.isUserInteractionEnabled = true
        label.addGestureRecognizer(UITapGestureRecognizer())
        label.gestureRecognizers?.first?.rx.event.subscribe(onNext: { _ in
            UIApplication.shared.open(URL(string: "https://convertio.co/mp3-caf/")!)
        }).disposed(by: label.rx.disposeBag)
        
        return view
    }
}

extension SoundsViewController: UIDocumentPickerDelegate {
    /// 选择音频文件或文件夹进行导入
    func pickerSoundFile() {
        if #available(iOS 14.0, *) {
            let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio, .folder], asCopy: false)
            documentPicker.delegate = self
            documentPicker.allowsMultipleSelection = true
            documentPicker.modalPresentationStyle = .pageSheet
            self.present(documentPicker, animated: true, completion: nil)
        } else {
            self.showSnackbar(text: "Requires iOS 14")
        }
    }
    
    // 文件或文件夹选择完成回调
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard !urls.isEmpty else { return }
        
        let supportedExtensions = Set(["caf", "wav", "m4a", "mp3", "aiff", "aac", "m4r"])
        var soundUrlsToImport: [URL] = []
        
        for rootUrl in urls {
            let canAccess = rootUrl.startAccessingSecurityScopedResource()
            defer {
                if canAccess {
                    rootUrl.stopAccessingSecurityScopedResource()
                }
            }
            
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: rootUrl.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    // 递归枚举文件夹下的所有音频文件
                    if let enumerator = FileManager.default.enumerator(
                        at: rootUrl,
                        includingPropertiesForKeys: [.isRegularFileKey],
                        options: [.skipsHiddenFiles]
                    ) {
                        for case let fileUrl as URL in enumerator {
                            if supportedExtensions.contains(fileUrl.pathExtension.lowercased()) {
                                soundUrlsToImport.append(fileUrl)
                            }
                        }
                    }
                } else {
                    if supportedExtensions.contains(rootUrl.pathExtension.lowercased()) {
                        soundUrlsToImport.append(rootUrl)
                    }
                }
            }
        }
        
        guard !soundUrlsToImport.isEmpty else {
            self.showSnackbar(text: "No supported audio files found")
            return
        }
        
        SVProgressHUD.show(withStatus: "Importing \(soundUrlsToImport.count) sound\(soundUrlsToImport.count == 1 ? "" : "s")...")
        
        let dispatchGroup = DispatchGroup()
        var importedCount = 0
        
        for audioUrl in soundUrlsToImport {
            dispatchGroup.enter()
            let canAccess = audioUrl.startAccessingSecurityScopedResource()
            let fileCoordinator = NSFileCoordinator()
            let err = NSErrorPointer(nilLiteral: ())
            
            fileCoordinator.coordinate(readingItemAt: audioUrl, error: err) { coordinatedUrl in
                if coordinatedUrl.pathExtension.lowercased() == "caf" {
                    DispatchQueue.main.async {
                        self.importSoundActionRelay.accept(coordinatedUrl)
                        importedCount += 1
                        dispatchGroup.leave()
                    }
                } else {
                    self.convertAudioToCAF(inputURL: coordinatedUrl) { convertedUrl in
                        if let convertedUrl {
                            self.importSoundActionRelay.accept(convertedUrl)
                            importedCount += 1
                        }
                        dispatchGroup.leave()
                    }
                }
            }
            
            if canAccess {
                audioUrl.stopAccessingSecurityScopedResource()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            SVProgressHUD.showSuccess(withStatus: "Imported \(importedCount) sound\(importedCount == 1 ? "" : "s")")
            SVProgressHUD.dismiss(withDelay: 1.5)
        }
    }
    
    /// 将音频文件转换为 CAF 格式
    /// - Parameters:
    ///   - inputURL: 输入音频文件的 URL
    ///   - completion: 转换完成后的回调，返回转换后的 CAF 文件 URL，如果转换失败则返回 nil
    func convertAudioToCAF(inputURL: URL, completion: @escaping (URL?) -> Void) {
        let fileName = inputURL.deletingPathExtension().lastPathComponent
        let tempFileName = "\(UUID().uuidString)_\(fileName).caf"
        let tempOutputURL = FileManager.default.temporaryDirectory.appendingPathComponent(tempFileName)
        let finalOutputURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(fileName).caf")

        do {
            if FileManager.default.fileExists(atPath: tempOutputURL.path) {
                try FileManager.default.removeItem(at: tempOutputURL)
            }

            let asset = AVAsset(url: inputURL)
            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
                completion(nil)
                return
            }

            let maxDuration = CMTime(seconds: 29.9, preferredTimescale: 600)
            if asset.duration > maxDuration {
                exportSession.timeRange = CMTimeRange(start: .zero, duration: maxDuration)
            }

            exportSession.outputFileType = .caf
            exportSession.outputURL = tempOutputURL

            exportSession.exportAsynchronously {
                DispatchQueue.main.async {
                    if exportSession.status == .completed {
                        try? FileManager.default.removeItem(at: finalOutputURL)
                        try? FileManager.default.moveItem(at: tempOutputURL, to: finalOutputURL)
                        completion(finalOutputURL)
                    } else {
                        try? FileManager.default.removeItem(at: tempOutputURL)
                        completion(nil)
                    }
                }
            }
        } catch {
            completion(nil)
        }
    }
}
