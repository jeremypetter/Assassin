//
//  HopperViewController.m
//  Assassin
//
//  Created by Jeremy Petter on 2015-06-01.
//  Copyright (c) 2015 Jeremy Petter. All rights reserved.
//

#import "HopperViewController.h"
#import "PlayerCollectionViewCell.h"
#import "GamestateViewController.h"
#import "TargetViewController.h"
#import "UserViewController.h"

@interface HopperViewController () <UITextFieldDelegate, UICollectionViewDataSource, UICollectionViewDelegate>

@property (weak, nonatomic) IBOutlet UITextField *gameTitleTextField;
@property (weak, nonatomic) IBOutlet UITextField *pinLabel;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *headerConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *footerConstraint;
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *headerTopMargin;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *footerBottomMargin;

@property (nonatomic) NSTimer *updateTimer;
@property (nonatomic) NSArray *players;
@property (nonatomic) NSDate *storedDate;


@end


@implementation HopperViewController



-(void)viewWillAppear:(BOOL)animated{
    [self.navigationController setNavigationBarHidden:YES animated:animated];
    [super viewWillAppear:animated];
}


- (void)viewDidLoad {
    [super viewDidLoad];
   
  
    
        
        PFQuery *playersInGame = [[PFQuery alloc] initWithClassName:[Player parseClassName]];
        [playersInGame whereKey:@"game" equalTo:self.game];
        [playersInGame findObjectsInBackgroundWithBlock:^(NSArray* results, NSError* error){
            self.players = results;
            [self.collectionView reloadData];
        }];
    self.storedDate = [[NSDate alloc]init];
    self.storedDate = [NSDate date];
    
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:10
                                                            target:self
                                                          selector:@selector(updateGameData)
                                                          userInfo:nil
                                                           repeats:YES];
   
    
    
    
    self.gameTitleTextField.delegate = self;
    self.gameTitleTextField.placeholder = [NSString stringWithFormat:@"%@'s Game",self.player.name];
    self.pinLabel.text = [NSString stringWithFormat:@"Join with code \"%@\"",self.game.joinPIN];
   
    [self hideHostUI];
    
    
}

-(void) hideHostUI{
    if ( self.player.host == NO ) {
        self.headerTopMargin.constant -=95;
        self.footerBottomMargin.constant -=75;
        
//        self.headerConstraint.constant = 0;
        self.gameTitleTextField.hidden = YES;
//        
//        self.footerConstraint.constant = 0;
        
    }
}

-(void) showHostUI{
    if ( self.player.host ) {
        if(self.headerTopMargin.constant != 0 || self.footerBottomMargin.constant != 0){
            self.headerTopMargin.constant = 0;
            self.footerBottomMargin.constant = 0;
            [UIView animateWithDuration:0.2 animations:^{
                
                //self.headerConstraint.constant = 75;
                self.gameTitleTextField.hidden = NO;
                
                //self.footerConstraint.constant = 75;
                [self.view layoutIfNeeded];
            }];
        }
        
    }
}

-(void)updateGameData {
    [self showHostUI];
    
    PFQuery *gameData = [[PFQuery alloc] initWithClassName:[Game parseClassName]];
    [gameData whereKey:@"objectId" equalTo:self.game.objectId];
    [gameData findObjectsInBackgroundWithBlock:^(NSArray *gameResults, NSError* error){
        Game *fetchedGame = [gameResults firstObject];
        if (fetchedGame.joinable){
            if (![self.storedDate isEqualToDate:fetchedGame.updatedAt])
            {
                PFQuery *playersInGame = [[PFQuery alloc] initWithClassName:[Player parseClassName]];
                
                [playersInGame whereKey:@"game" equalTo:self.game];
                [playersInGame findObjectsInBackgroundWithBlock:^(NSArray* results, NSError* error){
                    
                    NSArray* sortedResults = [results sortedArrayUsingComparator:^NSComparisonResult(Player* obj1, Player* obj2) {
                        if (obj1.createdAt.timeIntervalSince1970 > obj2.createdAt.timeIntervalSince1970){
                            return NSOrderedDescending;
                        } else if (obj1.createdAt.timeIntervalSince1970 > obj2.createdAt.timeIntervalSince1970)  {
                            return NSOrderedAscending;
                        }
                        return NSOrderedSame;
                    }];
                    int firstNewIndex = (int)self.players.count;
                    self.players = sortedResults;
                    NSMutableArray* paths = [@[] mutableCopy];
                    for (int i =firstNewIndex; i < self.players.count; i++ ){
                        NSIndexPath* path = [NSIndexPath indexPathForRow:i inSection:0];
                        [paths addObject:path];
                    }
                    [self.collectionView insertItemsAtIndexPaths:paths];
                    //[self.collectionView reloadData];
                    [self assignPlayerTargets];
                }];
                self.storedDate = fetchedGame.updatedAt;
                
            }
        } else {
            [self.updateTimer invalidate];
            self.updateTimer = nil;
            UITabBarController* tabController = [[UIStoryboard storyboardWithName:@"GameInProgress" bundle:nil] instantiateInitialViewController];
            UINavigationController* navController = [tabController.viewControllers firstObject];
            GamestateViewController* gameState = [navController.viewControllers firstObject];
            gameState.player = self.player;
            gameState.game = self.game;
            
            UINavigationController* targetNavController = tabController.viewControllers[1];
            TargetViewController* target = [targetNavController.viewControllers firstObject];
            target.player = self.player;
            
            [self showViewController:tabController sender:self];
        }
    }];
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    self.game.name = textField.text;
    return YES;
}

- (IBAction)startButtonPressed:(UIButton *)sender {
    [self.updateTimer invalidate];
    self.updateTimer = nil;
    
    [self.game fetchIfNeededInBackground];
    
    if ([self.gameTitleTextField.text isEqualToString:@""]) {
        self.game.name  = self.gameTitleTextField.placeholder;
    } else {
        self.game.name = self.gameTitleTextField.text;
    }
    
    self.game.joinable = NO;
    [self.game saveInBackground];
    
    UITabBarController* tabController = [[UIStoryboard storyboardWithName:@"GameInProgress" bundle:nil] instantiateInitialViewController];
    UINavigationController* navController = [tabController.viewControllers firstObject];
    GamestateViewController* gameState = [navController.viewControllers firstObject];
    gameState.player = self.player;
    gameState.game = self.game;
    
    UINavigationController* targetNavController = tabController.viewControllers[1];
    TargetViewController* target = [targetNavController.viewControllers firstObject];
    target.player = self.player;
    
    
    UINavigationController* userNavController = tabController.viewControllers[2];
    UserViewController* userView = [userNavController.viewControllers firstObject];
    userView.CurrentPlayer = self.player;
    
    [self showViewController:tabController sender:self];
    
    
    
    
    
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath{
    CGSize size = CGSizeMake(self.view.frame.size.width/2, self.view.frame.size.width/2);
    return size;
}

-(CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section{
    return 0;
}

-(CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section{
    return 0;
}


#pragma mark - CollectionView



- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView{
    return 1;
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [self.players count];
}

-(UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PlayerCollectionViewCell *cell =[collectionView dequeueReusableCellWithReuseIdentifier:@"Cell" forIndexPath:indexPath];
    cell.playerImageView.image = [UIImage imageNamed:@"placeholder"];
    
    Player *aPlayer = self.players[indexPath.row];
    
    cell.playerNameLabel.text = aPlayer.name;
    
    if (aPlayer.deadPhoto) {
        
        [aPlayer.deadPhoto getDataInBackgroundWithBlock:^(NSData* imageData, NSError* error){
            cell.playerImageView.image = [UIImage imageWithData:imageData];
        }];
    }
    else
    {
        dispatch_queue_t background_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_async(background_queue, ^{
            NSData* photoData = [aPlayer.alivePhoto getData];
            UIImage* photoImage = [UIImage imageWithData: photoData];
            dispatch_async(dispatch_get_main_queue(), ^{
                cell.playerImageView.image = photoImage;
            });
        });

//        [aPlayer.alivePhoto getDataInBackgroundWithBlock:^(NSData* imageData, NSError* error){
//            cell.playerImageView.image = [UIImage imageWithData:imageData];
//        }];
        
    }
    return cell;
}

- (void) assignPlayerTargets{
    
    dispatch_queue_t background_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_async(background_queue, ^{
        int count = 1;
        Player* player2;
        for (Player* player in self.players){
            [player fetchIfNeeded];
            if (count < self.players.count){
                player2 = self.players[count];
                [player fetchIfNeeded];
                player.target = player2;
            } else {
                player.target = self.players[0];
            }
            [player save];
            count++;
        }
    });

}

//- (void)assignPlayerTargets{
//    NSMutableArray *remainingPlayers = [self.players mutableCopy];
//    
//    int index = arc4random_uniform((int)[remainingPlayers count]);
//    Player* player1 = remainingPlayers[index];
//    Player* player0 = player1;
//    [remainingPlayers removeObjectAtIndex:index];
//    Player* player2;
//    while ([remainingPlayers count] > 0){
//        index = arc4random_uniform((int)[remainingPlayers count]);
//        player2 = remainingPlayers[index];
//        [remainingPlayers removeObjectAtIndex:index];
//        player1.target = player2;
//        [player1 saveInBackground];
//        //NSLog(@"%@'s target is %@.", player1.name, player1.target.name);
//        player1 = player2;
//    }
//    player2.target = player0;
//    [player2 saveInBackground];
//    NSLog(@"%@'s target is %@.", player2.name, player2.target.name);
//}

//#pragma mark - Navigation
//
//- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
//    
//}


@end
