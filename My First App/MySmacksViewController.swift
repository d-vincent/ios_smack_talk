//
//  MySmacksViewController.swift
//  Smack Talk
//
//  Created by Drew McDonald on 11/8/17.
//  Copyright © 2017 Drew McDonald. All rights reserved.
//

import UIKit
import Firebase

class MySmacksViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    var ref : DatabaseReference!
    var profileId = ""
    
    var smacks = [SmackObject]()
    
    @IBOutlet weak var smacksTableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        let preferences = UserDefaults.standard
        let uniqueIdKey = "uniqueIdKey"
        
        
        if preferences.object(forKey: uniqueIdKey) == nil {
            //  Doesn't exist
            profileId = UUID().uuidString
            preferences.set(profileId, forKey: uniqueIdKey)
            
        } else {
            profileId = (preferences.string(forKey: uniqueIdKey))!
        }
        
        weak var weakSelf = self
        
        
        ref = Database.database().reference()
        
        ref.child("smacks").queryOrdered(byChild: "authorId").queryEqual(toValue: profileId).observe(DataEventType.childAdded, with: {(snapshot) in
            
            var smack = SmackObject();
            
            if (snapshot.childSnapshot(forPath: "username").exists()){
                smack.userName = (snapshot.childSnapshot(forPath: "username").value as! String)
                
            }
            
            smack.authorId = (snapshot.childSnapshot(forPath: "authorId").value as! String)
            smack.content = (snapshot.childSnapshot(forPath: "content").value as! String)
            smack.replyCount = (snapshot.childSnapshot(forPath: "replyCount").value as! Int64)
            smack.timestamp = (snapshot.childSnapshot(forPath: "timestamp").value as! Int64)
            smack.voteCount = (snapshot.childSnapshot(forPath: "voteCount").value as! Int64)
            smack.id = snapshot.key
            
            weakSelf?.ref.child("profiles").child((weakSelf?.profileId)!).child("votes").child(snapshot.key).observeSingleEvent(of: DataEventType.value, with: { (voteSnap) in
                
                if (voteSnap.exists()){
                    smack.voteStatus = (voteSnap.value as! Int)
                }else {
                    smack.voteStatus = 0;
                }
                
                weakSelf?.ref.child("profiles").child(smack.authorId!).child("preferredTeamId").observeSingleEvent(of:DataEventType.value, with: { (logoSnap) in
                    
                    if (logoSnap.exists()){
                        smack.authorLogo = (logoSnap.value as! String)
                    }
                    weakSelf?.smacks.append(smack)
                    
                    weakSelf?.smacks.sort(by: { (lhs: SmackObject, rhs: SmackObject) -> Bool in
                        return lhs.timestamp! > rhs.timestamp!
                    })
                    
                    DispatchQueue.main.async {
                        weakSelf?.smacksTableView.reloadData()
                    }
                    
                    
                })
                
                
            })

            
            
            
            
            
        })

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let smack = smacks[indexPath.row]
        
        let cell = smacksTableView.dequeueReusableCell(withIdentifier: "smackCell", for: indexPath) as! SmackTableViewCell
        
        if (smack.voteStatus == 1){
            cell.upVoteButton.setImage(UIImage(named:"up_white"), for: UIControlState.normal)
            cell.downVoteButton.setImage(UIImage(named:"down_gray"), for: UIControlState.normal)
            cell.voteBackground.backgroundColor = UIColor .green
        }else if (smack.voteStatus == -1){
            cell.upVoteButton.setImage(UIImage(named:"up_gray"), for: UIControlState.normal)
            cell.downVoteButton.setImage(UIImage(named:"down_white"), for: UIControlState.normal)
            cell.voteBackground.backgroundColor = UIColor .red
        }else {
            cell.upVoteButton.setImage(UIImage(named:"up_gray"), for: UIControlState.normal)
            cell.downVoteButton.setImage(UIImage(named:"down_gray"), for: UIControlState.normal)
            cell.voteBackground.backgroundColor = UIColor .lightGray
        }
        cell.voteCount.text = String(smacks[indexPath.row].voteCount!)
        
        cell.content.text = smack.content
        cell.authorName.text = smack.userName
        
        let timeago = Date().toMillis() - smack.timestamp!
        let seconds = timeago / 1000
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24
        let time : String
        
        if (days > 0){
            time = String(days) + "d"
        }else if(hours > 0){
            time = String(hours) + "h"
        }else {
            time = String(minutes) + "m"
        }
        
        cell.timeSince.text = time
        if (smack.authorLogo != nil){
            cell.authorLogo.image = UIImage(named:"logo_" + smack.authorLogo!)
        }else {
            cell.authorLogo.image = nil
        }
        //        cell.timeSince
        
        cell.upVoteButton.tag = indexPath.row
        cell.upVoteButton.addTarget(self, action: #selector(upVote(_:)), for: .touchUpInside)
        
        cell.downVoteButton.tag = indexPath.row
        cell.downVoteButton.addTarget(self, action: #selector(downVote(_:)), for: .touchUpInside)
        
        cell.replyButton.tag = indexPath.row
        cell.replyCount.text = String(smack.replyCount!)
        
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return smacks.count
    }
    
    @objc func upVote(_ sender: UIButton){
        
        weak var weakSelf = self
        var smack = smacks[sender.tag]
        
        var cell: SmackTableViewCell
        cell = (smacksTableView.cellForRow(at: IndexPath(row:sender.tag, section: 0)) ) as! SmackTableViewCell
        
        switch smack.voteStatus! {
        case 0:
            sender.setImage(UIImage(named: "up_white"), for: UIControlState.normal)
            cell.downVoteButton.setImage(UIImage(named:"down_gray"), for: UIControlState.normal)
            cell.voteBackground.backgroundColor = UIColor .green
            
            smacks[sender.tag].voteStatus = 1
            smacks[sender.tag].voteCount = smack.voteCount! + 1
            cell.voteCount.text = String(smacks[sender.tag].voteCount!)
            
            weakSelf?.ref.child("profiles").child(profileId).child("votes").child(smack.id!).setValue(1)
            
            changeVoteCount(smackId: smack.id!, amount: 1)
            changeKarma(userId: smack.authorId!, amount: 1)
            changeKarma(userId: profileId, amount: 1)
            
            DispatchQueue.main.async {
                weakSelf?.smacksTableView.reloadData()
            }
            
        case 1:
            sender.setImage(UIImage(named: "up_gray"), for: UIControlState.normal)
            cell.downVoteButton.setImage(UIImage(named:"down_gray"), for: UIControlState.normal)
            cell.voteBackground.backgroundColor = UIColor .lightGray
            
            smacks[sender.tag].voteStatus = 0
            smacks[sender.tag].voteCount = smack.voteCount! - 1
            cell.voteCount.text = String(smacks[sender.tag].voteCount!)
            
            weakSelf?.ref.child("profiles").child(profileId).child("votes").child(smack.id!).setValue(0)
            
            changeVoteCount(smackId: smack.id!, amount: -1)
            changeKarma(userId: smack.authorId!, amount: -1)
            changeKarma(userId: profileId, amount: -1)
            
            DispatchQueue.main.async {
                weakSelf?.smacksTableView.reloadData()
            }
            
            
        case -1:
            sender.setImage(UIImage(named: "up_white"), for: UIControlState.normal)
            cell.downVoteButton.setImage(UIImage(named:"down_gray"), for: UIControlState.normal)
            cell.voteBackground.backgroundColor = UIColor .green
            
            smacks[sender.tag].voteStatus = 1
            smacks[sender.tag].voteCount = smack.voteCount! + 2
            cell.voteCount.text = String(smacks[sender.tag].voteCount!)
            
            weakSelf?.ref.child("profiles").child(profileId).child("votes").child(smack.id!).setValue(1)
            
            changeVoteCount(smackId: smack.id!, amount: 2)
            changeKarma(userId: smack.authorId!, amount: 2)
            changeKarma(userId: profileId, amount: 2)
            
            DispatchQueue.main.async {
                weakSelf?.smacksTableView.reloadData()
            }
            
        default:
            print("titties")
        }
        
    }
    
    @objc func downVote(_ sender: UIButton){
        
        weak var weakSelf = self
        var smack = smacks[sender.tag]
        
        var cell: SmackTableViewCell
        cell = (smacksTableView.cellForRow(at: IndexPath(row:sender.tag, section: 0)) ) as! SmackTableViewCell
        
        switch smack.voteStatus! {
        case 0:
            sender.setImage(UIImage(named: "down_white"), for: UIControlState.normal)
            cell.upVoteButton.setImage(UIImage(named:"up_gray"), for: UIControlState.normal)
            cell.voteBackground.backgroundColor = UIColor .red
            
            smacks[sender.tag].voteStatus = -1
            smacks[sender.tag].voteCount = smack.voteCount! - 1
            cell.voteCount.text = String(smacks[sender.tag].voteCount!)
            
            weakSelf?.ref.child("profiles").child(profileId).child("votes").child(smack.id!).setValue(-1)
            
            changeVoteCount(smackId: smack.id!, amount: -1)
            changeKarma(userId: smack.authorId!, amount: -1)
            changeKarma(userId: profileId, amount: -1)
            
            DispatchQueue.main.async {
                weakSelf?.smacksTableView.reloadData()
            }
            
        case 1:
            sender.setImage(UIImage(named: "down_white"), for: UIControlState.normal)
            cell.upVoteButton.setImage(UIImage(named:"up_gray"), for: UIControlState.normal)
            
            cell.voteBackground.backgroundColor = UIColor .red
            
            smacks[sender.tag].voteStatus = -1
            smacks[sender.tag].voteCount = smack.voteCount! - 2
            cell.voteCount.text = String(smacks[sender.tag].voteCount!)
            
            weakSelf?.ref.child("profiles").child(profileId).child("votes").child(smack.id!).setValue(-1)
            
            changeVoteCount(smackId: smack.id!, amount: -2)
            changeKarma(userId: smack.authorId!, amount: -2)
            changeKarma(userId: profileId, amount: -2)
            
            
            DispatchQueue.main.async {
                weakSelf?.smacksTableView.reloadData()
            }
            
        case -1:
            sender.setImage(UIImage(named: "down_gray"), for: UIControlState.normal)
            cell.upVoteButton.setImage(UIImage(named:"up_gray"), for: UIControlState.normal)
            cell.voteBackground.backgroundColor = UIColor .lightGray
            
            smacks[sender.tag].voteStatus = 0
            smacks[sender.tag].voteCount = smack.voteCount! + 1
            cell.voteCount.text = String(smacks[sender.tag].voteCount!)
            
            weakSelf?.ref.child("profiles").child(profileId).child("votes").child(smack.id!).setValue(0)
            
            changeVoteCount(smackId: smack.id!, amount: 1)
            changeKarma(userId: smack.authorId!, amount: 1)
            changeKarma(userId: profileId, amount: 1)
            
            DispatchQueue.main.async {
                weakSelf?.smacksTableView.reloadData()
            }
            
        default:
            print("titties")
        }
        
    }
    
    func changeKarma(userId id: String, amount: Int64){
        self.ref.child("profiles").child(id).child("karma").observeSingleEvent(of: DataEventType.value, with: { (snapshot) in
            if (snapshot.exists()){
                
                var currentKarma = (snapshot.value) as! Int64
                currentKarma += amount
                
                self.ref.child("profiles").child(id).child("karma").setValue(currentKarma)
                
            }else {
                self.ref.child("profiles").child(id).child("karma").setValue(amount)
            }
        })
    }
    
    func changeVoteCount(smackId id:String, amount: Int64){
        
        self.ref.child("smacks").child(id).child("voteCount").observeSingleEvent(of: DataEventType.value, with: { (snapshot) in
            var voteCount = (snapshot.value) as! Int64
            voteCount += amount
            self.ref.child("smacks").child(id).child("voteCount").setValue(voteCount)
            
        })
        
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
