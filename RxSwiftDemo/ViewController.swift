//
//  ViewController.swift
//  RxSwiftDemo
//
//  Created by M Imran on 19/06/2018.
//  Copyright © 2018 M Imran. All rights reserved.
//

import UIKit
import RxSwift

class ViewController: UIViewController {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var bodyLabel: UILabel!
    
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        realObservableExample()

    }
    
    //NOTE: Variable will never receive onError, and onComplete events
    func variables() {
        
        let name = Variable("Imran")
        name.asObservable().subscribe(onNext: { (value) in
            print("value has changed: \(value)")
        }) {
            // do some clean up code here
        }.disposed(by: disposeBag)
        name.value = "changed again"
    }
    
    func subjects() {
        let behaviorSubject = BehaviorSubject(value: 24)
        
        let disposable = behaviorSubject.subscribe(onNext: { newValue in
            print("behaviorSubject subscription: \(newValue)")
        }, onError: { error in
            print("error: \(error.localizedDescription)")
        }, onCompleted: {
            print("completed")
        }, onDisposed: {
            print("disposed")
        })
        
        disposable.disposed(by: disposeBag)
        
        behaviorSubject.onNext(34)
        behaviorSubject.onNext(48)
        behaviorSubject.onNext(48)
    }
    
    func fromObservable() {
        
        let numbers = Observable.from([1, 2, 3, 4, 5, 6, 7])
        numbers.subscribe(onNext: { number in
            print("Observable Subscription: \(number)")
        }).disposed(by: disposeBag)
    }
    
    func justObservable() {
        let observable = Observable.just(23)
        
        observable.subscribe(onNext: { number in
            print(number)
        }, onCompleted: {
            print("No more elements... ever")
        }).disposed(by: disposeBag)
    }
    
    func repeatingObservable() {
        
        let observable = Observable<Int>.interval(0.3, scheduler: MainScheduler.instance)
        observable.subscribe(onNext: { number in
            print(number)
        }, onCompleted: {
            print("No more elements... ever")
        }).disposed(by: disposeBag)
    }
    
    
    func customObservable() {
        
        //The observable
        let observerable = Observable<String>.create { observer in
            //The closure is called for every subscriber - by default
            print("~~ Observable logic being triggered ~~")
            
            //Do work on a background thread
            DispatchQueue.global().async {
                Thread.sleep(forTimeInterval: 1) //artificial delay
                
                observer.onNext("some value 23")
                observer.onCompleted()
            }
            
            return Disposables.create {
                //do something
                //network clean
                //fileio release
            }
        }
        
        observerable.subscribe(onNext: { someString in
            print("new value:  \(someString)")
        }).disposed(by: disposeBag)
        
        let observer = observerable.subscribe(onNext: { someString in
            print("Another Subscriber: \(someString)")
        })
        
        observer.disposed(by: disposeBag)
    }
    
    /////  Traits //////
    
    func traits_single() {
        
        let single = Single<String>.create { single -> Disposable in
            //do some logic here
            let success = true
            
            if success { //return a value
                single(.success("nice work!"))
            } else {
                let error = CustomError.someError
                single(.error(error))
            }
            
            return Disposables.create()
        }
        
        single.subscribe(onSuccess: { result in
            //do something with result
            print("single: \(result)")
        }, onError: { error in
            //do something for error
        }).disposed(by: disposeBag)
    }
    
    func traits_completable() {
        
        let completable = Completable.create { completable -> Disposable in
            //do logic here
            let success = true
            
            if success {
                completable(.completed)
            } else {
                let error = CustomError.someError
                completable(.error(error))
            }
            
            return Disposables.create()
        }
        
        completable.subscribe(onCompleted: {
            //handle on complete
            print("Completable completed")
        }, onError:{ error in
            //do something for error
        }).disposed(by: disposeBag)
    }
    
    func traits_maybe() {
        
        let maybe = Maybe<String>.create { maybe in
            //do something
            let success = true
            let hasResult = true
            
            
            if success {
                if hasResult {
                    maybe(.success("some result"))
                } else {
                    maybe(.completed) //no result
                }
            } else {
                let someError = CustomError.someError
                maybe(.error(someError))
            }
            
            return Disposables.create()
        }
        
        maybe.subscribe(onSuccess: { result in
            //do something with result
            print("Maybe - result: \(result)")
        }, onError: { error in
            //do something with the error
        }, onCompleted: {
            //do something about completing
            print("Maybe - completed")
        }).disposed(by: disposeBag)
    }
}


enum CustomError: Error {
    case someError
    case noDataFromServer
}

//MARK: - Real Observable Example
extension ViewController {
    
    func realObservableExample() {
        loadPost().asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] posting in
                self?.titleLabel.text = posting.title
                self?.bodyLabel.text  = posting.body
                }, onError: { [weak self] error in
                    print("❗️ an error occured: \(error.localizedDescription)")
                    self?.titleLabel.text = ""
                    self?.bodyLabel.text  = ""
            }).disposed(by: disposeBag)
    }
    
    //usually done in the network layer
    func loadPost() -> Observable<Post> {
        return Observable.create { observer in
            let url = URL(string: "https://jsonplaceholder.typicode.com/posts/5")!
            
            let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                guard error == nil else { observer.onError(error!) ; return }
                guard let data = data else { observer.onError(CustomError.noDataFromServer) ; return }
                guard let strongSelf = self else { return }
                
                let posting = strongSelf.parse(data)
                
                observer.onNext(posting)
                observer.onCompleted()
            }
            
            task.resume()
            
            return Disposables.create {
                task.cancel()
            }
        }
    }
    
    func parse(_ data: Data) -> Post {
        let json = try! JSONSerialization.jsonObject(with: data) as! [String: Any]  //In production you would not try! or as!
        
        let posting = Post(userId: try! json["userId"] as! Int,
                              id:  try! json["id"] as! Int,
                              title:  try! json["title"] as! String,
                              body:  try! json["body"] as! String)
        
        return posting
        
    }
}
