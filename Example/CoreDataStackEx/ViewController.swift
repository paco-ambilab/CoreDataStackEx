//
//  ViewController.swift
//  CoreDataStackEx
//
//  Created by paco89lol@gmail.com on 06/03/2020.
//  Copyright (c) 2020 paco89lol@gmail.com. All rights reserved.
//

import UIKit
import CoreData
import CoreDataStackEx

//class ViewController: UIViewController {
//
//}

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    var connnect: CoreDataStack?

    weak var tableView: UITableView!

    lazy var users: [User] = {
        return userList()
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        connnect = makeConnectionFromCoreData()
        let tableView = UITableView(frame: .zero)
        self.tableView = tableView
        self.view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        tableView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        bindUI()
    }

    func bindUI() {
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsSelection = true
//        tableView.setEditing(true, animated: false)
        self.navigationItem.rightBarButtonItem =
        UIBarButtonItem(barButtonSystemItem: .add,
        target: self,
        action:
          #selector(ViewController.addBtnAction))
//        editBtnAction()
    }

    @objc func editBtnAction() {
        tableView.setEditing(!tableView.isEditing, animated: true)
        if (!tableView.isEditing) {
            // 顯示編輯按鈕
            self.navigationItem.leftBarButtonItem =
                UIBarButtonItem(barButtonSystemItem: .edit,
              target: self,
              action:
                #selector(ViewController.editBtnAction))

            // 顯示新增按鈕
            self.navigationItem.rightBarButtonItem =
              UIBarButtonItem(barButtonSystemItem: .add,
              target: self,
              action:
                #selector(ViewController.addBtnAction))
        } else {
            // 顯示編輯完成按鈕
            self.navigationItem.leftBarButtonItem =
              UIBarButtonItem(barButtonSystemItem: .done,
                target: self,
                action:
                  #selector(ViewController.editBtnAction))

            // 隱藏新增按鈕
            self.navigationItem.rightBarButtonItem = nil
        }
    }

    @objc func addBtnAction() {
        showAlert { [weak self] (username, email) in

            guard let user = self?.createUser(name: username, email: email) else {
                return
            }
            self?.users.append(user)
            let idx = (self?.users.count ?? 1) - 1
            self?.tableView.beginUpdates()
            self?.tableView.insertRows(
                at: [(NSIndexPath(row: idx, section: 0) as IndexPath)],
                with: .fade)
            self?.tableView.endUpdates()
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return users.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as UITableViewCell
        cell.textLabel?.text = "name:\(users[indexPath.row].name ?? "") email: \(users[indexPath.row].email ?? "")"
        return cell
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let user = users[indexPath.row]
            if deleteUsers(users: [user]) {
                users.remove(at: indexPath.row)
                tableView.beginUpdates()
                tableView.deleteRows(at: [indexPath], with: .fade)
                tableView.endUpdates()
            }
        }
    }

    func makeConnectionFromCoreData() -> CoreDataStack {
        let bundle = Bundle(for: type(of: self))
        let instance = CoreDataStack(configuration: CoreDataStackConfig(storeType: .sqlite, bundle: bundle, modelName: "testmodel", accessGroup: nil))
        try! instance.prepare()
        return instance
    }

    func user(id: String) -> User? {
        let fetchRequest = User.fetchRequest() as NSFetchRequest<User>
        fetchRequest.predicate = NSPredicate(format:"id = %@",id)
        return connnect?.makeRequest().fetch(fetchRequest: fetchRequest).object.first
    }

    func userList() -> [User] {
        return connnect?.makeRequest().fetchAll(type: User.self).object ?? []
    }

    func createUser(name: String, email: String) -> User? {
        return connnect?.makeRequest().create(createBlock: { (user: User, _) in
            user.name = name
            user.email = email
            }).object.first
    }

    func deleteUsers(users: [User]) -> Bool {
        for user in users {
            guard connnect?.makeRequest().delete(byObject: user) == nil else {
                return false
            }
        }
        return true
    }

    func deleteUser(_ user: User) -> Bool {
        return connnect?.makeRequest().delete(byObject: user) == nil
    }

    func deleteUser(id: String, completion: @escaping ((Error?) -> Void)) {

        connnect?.makeTransaction().transactionBlock({ (context, observer) in

            // create query logic
            let fetchRequest = User.fetchRequest() as NSFetchRequest<User>
            fetchRequest.predicate = NSPredicate(format:"id = %@",id)

            // fetch from coreData
            let fetchResult = context.fetch(fetchRequest: fetchRequest)

            guard fetchResult.error == nil else {
                // rollback
                observer.onAbort(error: fetchResult.error)
                return
            }

            guard let user = fetchResult.object.first else {
                // save
                observer.onSuccess()
                return
            }
            // delete from coreData
            let error = context.delete(byObject: user)

            guard error == nil else {
                // rollback
                observer.onAbort(error: error)
                return
            }
            // save
            observer.onSuccess()

        }).run(completion: { (error) in
            completion(error)
        })
    }

    func showAlert(okActionCompletion: @escaping ((String, String) -> Void)) {
        let controller = UIAlertController(title: "Create User", message: "Please enter username and password", preferredStyle: .alert)
        controller.addTextField { (textField) in
            textField.placeholder = "username"
            textField.keyboardType = UIKeyboardType.namePhonePad
        }
        controller.addTextField { (textField) in
            textField.placeholder = "email"
            textField.keyboardType = UIKeyboardType.namePhonePad
        }
        let okAction = UIAlertAction(title: "OK", style: .default) { (_) in
            let username = controller.textFields?[0].text
            let email = controller.textFields?[1].text
            okActionCompletion(username ?? "", email ?? "")
        }
        controller.addAction(okAction)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        controller.addAction(cancelAction)
        present(controller, animated: true, completion: nil)
    }
}
