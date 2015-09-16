import UIKit

final class SettingViewController: UIViewController {

    private var tableView:UITableView!
    
    var texts = ["hello", "world", "hello", "Swift"]
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView = UITableView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height))
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "Cell")

        view.addSubview(tableView)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    
    func tableView(tableView: UITableView!, numberOfRowsInSection section: Int) -> Int  {
        return texts.count
    }
    
    func tableView(tableView: UITableView?, cellForRowAtIndexPath indexPath:NSIndexPath!) -> UITableViewCell! {
        let cell: UITableViewCell = UITableViewCell(style: UITableViewCellStyle.Subtitle, reuseIdentifier: "Cell")
        cell.textLabel!.text = "hoge"
        return cell
    }
    
    func tableView(tableView: UITableView?, didSelectRowAtIndexPath indexPath:NSIndexPath!) {
        var text: String = texts[indexPath.row]
        print(text)
    }

}
