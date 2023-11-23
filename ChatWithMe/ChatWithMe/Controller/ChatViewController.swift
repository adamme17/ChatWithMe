//
//  ChatViewController.swift
//  ChatWithMe
//
//  Created by Adam Bokun on 7.05.22.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import GameController

struct Message: MessageType {
    public var sender: SenderType
    public var messageId: String
    public var sentDate: Date
    public var kind: MessageKind
}

extension MessageKind {
    var messageKindString : String {
        switch self {
            
        case .text(_):
            return "text"
        case .attributedText(_):
            return "attributed_text"
        case .photo:
            return "photo"
        case .video(_):
            return "video"
        case .location(_):
            return "location"
        case .emoji(_):
            return "emoji"
        case .audio(_):
            return "audio"
        case .contact(_):
            return "contact"
        case .linkPreview(_):
            return "link_preview"
        case .custom(_):
            return "custom"
        }
    }
}

struct Sender: SenderType {
    public var photoURL: String
    public var senderId: String
    public var displayName: String
}

struct Media: MediaItem {
    var url: URL?
    var image: UIImage?
    var placeholderImage: UIImage
    var size: CGSize
}

class ChatViewController: MessagesViewController {
    
    public static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        formatter.locale = .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return formatter
    }()
    
    public let otherUserEmail: String
    private let conversationId: String?
    public var isNewConversation = false
    private var senderPhotoURL: URL?
    private var otherUserPhotoURL: URL?
    
    private var messages = [Message]()
    
    private var selfSender: Sender? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress:  email)
        
        return Sender(photoURL: "",
                      senderId: safeEmail,
                      displayName: "Me")
    }
    
    init(with email: String, id: String?) {
        self.conversationId = id
        self.otherUserEmail = email
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .red
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
        messageInputBar.delegate = self
        setupInputButton()
    }
    
    private func setupInputButton() {
        let button = InputBarButtonItem()
        button.setSize(CGSize(width: 35, height: 35), animated: false)
        button.setImage(UIImage(systemName: "paperclip"), for: .normal)
        button.onTouchUpInside { [weak self] _ in
            self?.presentInputActionSheet()
        }
        messageInputBar.setLeftStackViewWidthConstant(to: 36, animated: false)
        messageInputBar.setStackViewItems([button], forStack: .left, animated: false)
    }
    
    private func presentInputActionSheet() {
        let actionSheet = UIAlertController(title: "Attach Photo",
                                            message: "Where would you like to attach a photo from",
                                            preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: { [weak self] _ in
            
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true)
            
        }))
        actionSheet.addAction(UIAlertAction(title: "Photo Library", style: .default, handler: { [weak self] _ in
            
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true)
            
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(actionSheet, animated: true)
    }
    
    
    private func listenForMessages(id: String, shouldScrollToBottom: Bool) {
        DatabaseManager.shared.getAllMessagesForConversation(with: id,
                                                             completion: { [weak self] result in
            //            guard let self = self else { return }
            switch result {
            case .success(let messages):
                print("Success in getting messages")
                guard !messages.isEmpty else {
                    print("messages are empty")
                    return
                }
                self?.messages = messages
                
                DispatchQueue.main.async {
                    self?.messagesCollectionView.reloadDataAndKeepOffset()
                    
                    if shouldScrollToBottom {
                        self?.messagesCollectionView.scrollToBottom()
                    }
                }
                
            case .failure(let error):
                print("failed to get messages: \(error)")
            }
        })
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageInputBar.inputTextView.becomeFirstResponder()
        
        if let conversationId = conversationId {
            listenForMessages(id: conversationId, shouldScrollToBottom: true)
        }
    }
    
}

extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard let image = info[UIImagePickerController.InfoKey.editedImage] as? UIImage,
              let imageData = image.pngData(),
              let messageId = createMessageId(),
              let conversationId = conversationId,
              let name = self.title,
              let selfSender = selfSender else {
            return
        }
        
        let fileName = "photo_message_" + messageId.replacingOccurrences(of: " ", with: "-") + ".png"
        
        StorageManager.shared.uploadMessagePhoto(with: imageData,
                                                 fileName: "",
                                                 completion: { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            
            switch result {
            case .success(let urlString):
                print("Uploaded message photo: \(urlString)")
                
                guard let url = URL(string: urlString),
                      let placeholder = UIImage(systemName: "plus") else {
                    return
                }
                
                let media = Media(url: url,
                                  image: nil,
                                  placeholderImage: placeholder,
                                  size: .zero)
                
                let message = Message(sender: selfSender,
                                      messageId: messageId,
                                      sentDate: Date(),
                                      kind: .photo(media))
                
                DatabaseManager.shared.sendMessage(to: conversationId,
                                                   otherUserEmail: strongSelf.otherUserEmail,
                                                   name: name,
                                                   newMessage: message,
                                                   completion: { success in
                    
                    if success {
                        print("sent photo message")
                    } else {
                        print("failed to send photo message")
                    }
                    
                    
                })
            case .failure(let error):
                print("message photo upload error: \(error)")
            }
        })
    }
}

extension ChatViewController: InputBarAccessoryViewDelegate {
    
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard !text.replacingOccurrences(of: " ", with: "").isEmpty,
              let selfSender = self.selfSender else { return
        }
        
        inputBar.inputTextView.text.removeAll()
        
        let messageId = UUID().uuidString
        print("Sending: \(text)")
        
        let mmessage = Message(sender: selfSender,
                               messageId: messageId,
                               sentDate: Date(),
                               kind: .text(text))
        
        //Send message
        if isNewConversation {
            
            DatabaseManager.shared.createNewConversation(with: otherUserEmail,
                                                         name: self.title ?? "User",
                                                         firstMessage: mmessage,
                                                         completion: { [weak self] success in
                if success {
                    print("message sent")
                    self?.isNewConversation = false
                } else {
                    print("failed to send")
                }
            })
        }
        else {
            guard let conversationId = conversationId, let name = self.title else {
                return
            }
            DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: otherUserEmail, name: name, newMessage: mmessage, completion: { success in
                if success {
                    print("message sent")
                } else {
                    print("failed to send")
                }
            })
        }
    }
    
    private func createMessageId() -> String? {
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        
        let safeCurrentEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail )
        
        let dateString = Self.dateFormatter.string(from: Date())
        
        let newIdentifier = "\(otherUserEmail)_\(safeCurrentEmail)_\(dateString)"
        print("created message id: \(newIdentifier)")
        return newIdentifier
    }
}

extension ChatViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate {
    
    func currentSender() -> SenderType {
        if let sender = selfSender {
            return sender
        }
        
        fatalError("Self Sender is nil, email should be cached")
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        return messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessagesCollectionView) -> Int {
        return messages.count
    }
    
    func configureMediaMessageImageView(_ imageView: UIImageView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        guard let message = message as? Message else {
            return
        }

        switch message.kind {
        case .photo(let media):
            guard let imageUrl = media.url else {
                return
            }
            imageView.sd_setImage(with: imageUrl, completed: nil)
        default:
            break
        }
    }
    
    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {

            let sender = message.sender

            if sender.senderId == selfSender?.senderId {
                // show our image
                if let currentUserImageURL = self.senderPhotoURL {
                    avatarView.sd_setImage(with: currentUserImageURL, completed: nil)
                }
                else {
                    // images/safeemail_profile_picture.png
                    guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
                        return
                    }

                    let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
                    let path = "images/\(safeEmail)_profile_picture.png"

                    // fetch url
                    StorageManager.shared.dowmloadURL(for: path, completion: { [weak self] result in
                        switch result {
                        case .success(let url):
                            self?.senderPhotoURL = url
                            DispatchQueue.main.async {
                                avatarView.sd_setImage(with: url, completed: nil)
                            }
                        case .failure(let error):
                            print("\(error)")
                        }
                    })
                }
            }
            else {
                // other user image
                if let otherUsrePHotoURL = self.otherUserPhotoURL {
                    avatarView.sd_setImage(with: otherUsrePHotoURL, completed: nil)
                }
                else {
                    // fetch url
                    let email = self.otherUserEmail

                    let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
                    let path = "images/\(safeEmail)_profile_picture.png"

                    // fetch url
                    StorageManager.shared.dowmloadURL(for: path, completion: { [weak self] result in
                        switch result {
                        case .success(let url):
                            self?.otherUserPhotoURL = url
                            DispatchQueue.main.async {
                                avatarView.sd_setImage(with: url, completed: nil)
                            }
                        case .failure(let error):
                            print("\(error)")
                        }
                    })
                }
            }

        }
}

extension ChatViewController: MessageCellDelegate {
    func didTapMessage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else {
            return
        }

        let message = messages[indexPath.section]
        let requestManager = RequestManager()

        switch message.kind {
        case .text(let text):
            requestManager.analyze(endPoint: .analyze(message: text)) { response in
                switch response {
                case .success(let result):
                    
                    print(result.emotion)
                    
                    var analyzedText = ""
                    
                    if result.emotion == "neutral" {
                        analyzedText = "Seems that this message is neutral"
                    }
                    if result.emotion == "fear" {
                        analyzedText = "The author of the message seems to be scared😨"
                    }
                    if result.emotion == "anger" {
                        analyzedText = "The author of the message seems to be angry😠"
                    }
                    if result.emotion == "joy" {
                        analyzedText = "The author of the message seems to be very happy😊"
                    }
                    if result.emotion == "sadness" {
                        analyzedText = "The message seems sad😢"
                    }
                    
                    let alert = UIAlertController(title: result.emotion,
                                                  message: analyzedText,
                                                  preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK",
                                                      style: .default,
                                                      handler: nil))
                    DispatchQueue.main.async {
                        self.present(alert, animated: true, completion: nil)
                    }
               
                case .failure(let error):
                    print(error)
                }

            }
            print(text)
        case .attributedText(let text):
            let message = text.length
        case .location(let locationData):
            let coordinates = locationData.location.coordinate
            let vc = LocationPickerViewController(coordinates: coordinates)
            
            vc.title = "Location"
            navigationController?.pushViewController(vc, animated: true)
        default:
            break
        }
    }

    func didTapImage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else {
            return
        }

        let message = messages[indexPath.section]

        switch message.kind {
        case .photo(let media):
            guard let imageUrl = media.url else {
                return
            }
            let vc = PhotoViewerViewController(with: imageUrl)
            navigationController?.pushViewController(vc, animated: true)
        default:
            break
        }
    }
}






