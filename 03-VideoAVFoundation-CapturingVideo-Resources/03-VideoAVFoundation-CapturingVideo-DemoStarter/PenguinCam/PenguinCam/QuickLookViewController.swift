//
//  QuickLookViewController.swift
//  PenguinCam
//
//  Created by Michael Briscoe on 1/14/16.
//  Copyright © 2016 Razeware LLC. All rights reserved.
//

import UIKit

class QuickLookViewController: UIViewController {
  
  @IBOutlet weak var quickLookImage: UIImageView!
  var photoImage: UIImage!
  
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
  
    override var prefersStatusBarHidden: Bool {
        return true
    }

  
  override func viewDidLoad() {
    super.viewDidLoad()
    if photoImage != nil {
      quickLookImage.image = photoImage
    }
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  
    @IBAction func didTapCloseQuickLookButton(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }
  
}
