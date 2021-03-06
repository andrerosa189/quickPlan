//
//  ChatVC.swift
//  quickPlan
//
//  Created by André Rosa on 23/03/2018.
//  Copyright © 2018 Andre Rosa. All rights reserved.
//

import UIKit

class ChatVC: UIViewController, UITableViewDelegate, UITableViewDataSource {

    // MARK: Outlets
    @IBOutlet weak var menuBtn: UIButton!
    @IBOutlet weak var sendMessageBtn: UIButton!
    @IBOutlet weak var messageTxtBox: UITextField!
    @IBOutlet weak var tableView: UITableView!
    
    // MARK: Variables
    var textFieldDelegate = TextFieldDelegate()
    var isTyping = false
    var navigateItemTitle: String = ""
    // MARK: Load empty list view from nib
    let emptyListPlaceholder: UIView? = Bundle.main.loadNibNamed("EmptyListPlaceholder", owner: nil, options: nil)?.first as? UIView
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // MARK: Socket to listen messages on chat
        SocketService.instance.getChatMessage { (newMessage) in
            if newMessage.channelId == MessageService.instance.selectedChannel?.id && AuthService.instance.isLoggedIn {
                MessageService.instance.messages.append(newMessage)
                self.tableView.reloadData()
                self.checkEmptyList()
                if MessageService.instance.messages.count > 0 {
                    self.scrollToTableBottom(animated: true)
                }
            }
        }
        
        // MARK: Socket to listen when user start to type
        SocketService.instance.getTypingUsers { (typingUsers) in
            guard let channelId = MessageService.instance.selectedChannel?.id else {return}
            var names = ""
            var numberOfTypers = 0
            for (typingUser,channel) in typingUsers {
                if typingUser != UserDataService.instance.name && channel == channelId {
                    if names == "" {
                        names = typingUser
                    } else {
                        names = "\(names), \(typingUser)"
                    }
                    numberOfTypers += 1
                }
            }
            
            if numberOfTypers > 0 && AuthService.instance.isLoggedIn == true {
                var verb = "is"
                if numberOfTypers > 1 {
                    verb = "are"
                }
                self.navigationItem.title = "\(names) \(verb) typing"
            } else {
                self.navigationItem.title = self.navigateItemTitle
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unsubscribeFromNotificationCenter()
    }
    
    func setupView(){
        tableView.delegate = self
        tableView.dataSource = self
        
        // MARK: Setup Row Height automatically
        // Obs: the number of lines in label has to be 0
        tableView.estimatedRowHeight = 80;
        tableView.rowHeight = UITableViewAutomaticDimension
        
        view.bindToKeyboard()
        configMenuBtn()
        configNavViewUI()
        
        sendMessageBtn.isEnabled = false
        messageTxtBox.delegate = textFieldDelegate
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(ChatVC.handleTap))
        view.addGestureRecognizer(tap)
        
        subscribeToNotificationCenter()
        
        if AuthService.instance.isLoggedIn{
            AuthService.instance.findUserByEmail { (success) in
                NotificationCenter.default.post(name: Constants.Notifications.UserDataDidChange, object: nil)
            }
        }
    }
    
    func subscribeToNotificationCenter() {
        NotificationCenter.default.addObserver(self, selector: #selector(ChatVC.userDataDidChange(_:)), name: Constants.Notifications.UserDataDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ChatVC.channelSelected(_:)), name: Constants.Notifications.ChannelSelected, object: nil)
    }
    
    func unsubscribeFromNotificationCenter() {
        NotificationCenter.default.removeObserver(self, name: Constants.Notifications.UserDataDidChange, object: nil)
        NotificationCenter.default.removeObserver(self, name: Constants.Notifications.ChannelSelected, object: nil)
    }
    
    @objc func handleTap(){
        view.endEditing(true)
    }
    
    @objc func userDataDidChange(_ notif: Notification){
        if AuthService.instance.isLoggedIn{
            onLoginGetMessages()
        } else {
            tableView.reloadData()
            checkEmptyList()
        }
    }
    
    @objc func channelSelected(_ notif: Notification){
        updateWithChannel()
    }
    
    func updateWithChannel(){
        // MARK: If can't find and string set and empty string
        let channelName = MessageService.instance.selectedChannel?.channelTitle ?? ""
        self.navigationItem.title = "#\(channelName)"
        navigateItemTitle = "#\(channelName)"
        getMessages()
    }
    
    // MARK: MessageBox
    @IBAction func messageBoxEditing(_ sender: Any) {
        guard let channelId = MessageService.instance.selectedChannel?.id else {return}
        if messageTxtBox.text == "" {
            isTyping = false
            sendMessageBtn.isEnabled = false
    
            // MARK: Emit socket when user stop type
            SocketService.instance.socket.emit(Constants.SocketsEvents.StopType, UserDataService.instance.name, channelId)
        } else {
            if isTyping == false {
                sendMessageBtn.isEnabled = true
                // MARK: Emit socket when user start type
                SocketService.instance.socket.emit(Constants.SocketsEvents.StartType, UserDataService.instance.name, channelId)
            }
            isTyping = true
        }
    }
    
    
    func onLoginGetMessages(){
        MessageService.instance.findAllChannel { (success) in
            if success {
                if MessageService.instance.channels.count > 0 {
                    MessageService.instance.selectedChannel = MessageService.instance.channels[0]
                    self.updateWithChannel()
                } else {
                    // Do something because there's no channels
                }
            }
        }
    }
    
    func getMessages(){
        guard let channelId = MessageService.instance.selectedChannel?.id else {return}
        MessageService.instance.findAllMessagesForChannel(channelId: channelId) { (success) in
            if success{
                self.tableView.reloadData()
                self.checkEmptyList()
                if MessageService.instance.messages.count > 0 {
                    self.scrollToTableBottom(animated: false)
                }
            }
        }
    }
    
    // MARK: Function to check if the table is empty to put the placeholder
    
    func checkEmptyList() {
        if MessageService.instance.messages.count > 0 {
            self.tableView.backgroundView = nil
        } else {
            self.tableView.backgroundView = emptyListPlaceholder
        }
    }
    
    
    // MARK: Set add gesture recognizer to button
    func configMenuBtn(){
        menuBtn.addTarget(self.revealViewController(), action: #selector(SWRevealViewController.revealToggle(_:)), for: .touchUpInside)
        view.addGestureRecognizer(self.revealViewController().panGestureRecognizer())
        view.addGestureRecognizer(revealViewController().tapGestureRecognizer())
    }

    
    @IBAction func sendMessagePressed(_ sender: Any) {
        if AuthService.instance.isLoggedIn {
            guard let channelId = MessageService.instance.selectedChannel?.id else {return}
            guard let message = messageTxtBox.text else {return}
            
            SocketService.instance.addMessage(messageBody: message, userId: UserDataService.instance.id, channelId: channelId) { (success) in
                if success {
                    self.messageTxtBox.text = ""
                    self.sendMessageBtn.isEnabled = false
                    SocketService.instance.socket.emit(Constants.SocketsEvents.StopType, UserDataService.instance.name, channelId)
                    self.isTyping = false
                }
            }
        }
    }
    
    // MARK: func to scroll table to a specific index path (cell)
    func scrollToTableBottom(animated: Bool){
        if MessageService.instance.messages.count > 0 {
            let endIndex = IndexPath(row: MessageService.instance.messages.count - 1, section: 0)
            self.tableView.scrollToRow(at: endIndex, at: .bottom, animated: animated)
        }
    }
    
    func configNavViewUI(){
        // MARK: Only execute the code if there's a navigation controller
        if navigationController == nil{
            return
        }

        // MARK: Remove border in navigationBar
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        self.navigationController?.navigationBar.shadowImage = UIImage()

        // MARK: Create a navView to add to the navigation bar
//        let navView = UIView()
//
//        // MARK: Create the label
//        let label = UILabel()
//        label.text = "  nodeJS"
//        label.sizeToFit()
//        label.center = navView.center
//        label.font = UIFont(name: "Ubuntu-Medium", size: 17.0)
//        label.textColor = #colorLiteral(red: 0.1953743398, green: 0.2127636969, blue: 0.2761407495, alpha: 1)
//        label.textAlignment = NSTextAlignment.center
//
//        // MARK: Create the image view
//        let image = UIImageView()
//        image.image = UIImage(named: "small_logo.png")
//        // MARK: To maintain the image's aspect ratio:
//        let imageAspect = image.image!.size.width/image.image!.size.height
//        // MARK: Setting the image frame so that it's immediately before the text:
//        image.frame = CGRect(x: label.frame.origin.x-label.frame.size.height*imageAspect, y: label.frame.origin.y, width: label.frame.size.height*imageAspect, height: label.frame.size.height)
//        image.contentMode = UIViewContentMode.scaleAspectFit
//
//        // MARK: Add both the label and image view to the navView
//        navView.addSubview(label)
//        navView.addSubview(image)
//
//        // MARK: Set the navigation bar's navigation item's titleView to the navView
//        self.navigationItem.titleView = navView
//
//        // MARK: Set the navView's frame to fit within the titleView
//        navView.sizeToFit()
    }
    
    // MARK: Delegate methods
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: Constants.Identifiers.MessageCell, for: indexPath) as? MessageCell {
            let message = MessageService.instance.messages[indexPath.row]
            cell.configureCell(message: message)
            return cell
        } else {
            return UITableViewCell()
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return MessageService.instance.messages.count
    }
    
    
    
}







