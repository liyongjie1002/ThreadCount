//
//  ViewController.m
//  ThreadCount
//
//  Created by mac on 2024/2/18.
//
/*
 
 参考链接：https://cloud.tencent.com/developer/ask/sof/109216514
 
 经过测试，GCD的全局队列自动将线程数量限制在一个合理的数目。与此相比，自建队列创建的线程数量很大.

 考虑到线程数量太大，CPU调度成本会增加。

 因此，建议小型应用程序尽可能使用全局队列来管理任务；大型应用程序可以根据其实际情况决定合适的解决方案。

 */


#import "ViewController.h"
#import <mach/mach.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)printThreadCount {
    kern_return_t kr = { 0 };
    thread_array_t thread_list = { 0 };
    mach_msg_type_number_t thread_count = { 0 };
    kr = task_threads(mach_task_self(), &thread_list, &thread_count);
    if (kr != KERN_SUCCESS) {
        return;
    }
    NSLog(@"threads count:%@", @(thread_count));
    
    kr = vm_deallocate( mach_task_self(), (vm_offset_t)thread_list, thread_count * sizeof(thread_t) );
    if (kr != KERN_SUCCESS) {
        return;
    }
    return;
}

- (IBAction)test1 {
    NSMutableSet<NSThread *> *set = [NSMutableSet set];
    for (int i=0; i < 1000; i++) {
        dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
        dispatch_async(queue, ^{
            NSThread *thread = [NSThread currentThread];
            [set addObject:[NSThread currentThread]];
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"start:%@", thread);
                NSLog(@"GCD threads count:%lu",(unsigned long)set.count);
                [self printThreadCount];
            });
            
            NSDate *date = [NSDate dateWithTimeIntervalSinceNow:10];
            long i=0;
            while ([date compare:[NSDate date]]) {
                i++;
            }
            [set removeObject:thread];
            NSLog(@"end:%@", thread);
        });
    }
}

/*
 测试后，最大线程数为64。
 所有全局队列都可以同时创建多达64个线程。

 全局队列是通过_pthread_workqueue_addthreads方法添加的。但是，在内核(插件)中使用此方法添加的线程数量是有限制的。

 限制的具体代码如下所示：

 #define MAX_PTHREAD_SIZE 64*1024

 根据Apple-Docs-线程编程指南-线程创建成本：1线程分配1k核，总大小限制在64k，由此可以推断出结果是64个线程。

 */

- (IBAction)test2 {
    NSMutableSet<NSThread *> *set = [NSMutableSet set];
    for (int i=0; i < 1000; i++) {
        dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
        dispatch_async(queue, ^{
            NSThread *thread = [NSThread currentThread];
            [set addObject:[NSThread currentThread]];
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"start:%@", thread);
                NSLog(@"GCD threads count:%lu",(unsigned long)set.count);
                [self printThreadCount];
            });
            // thread sleep for 10s
            [NSThread sleepForTimeInterval:10];
            [set removeObject:thread];
            NSLog(@"end:%@", thread);
            return;
        });
    }
}
/*
 所有类型(并发队列和串行队列)都可以同时创建最多512个线程。
 提到的512是gcd的极限。在打开512个gcd线程后，仍然可以使用NSThread打开它们。

 所以上面的图表

 目前应该是512,516 = 512(max) +主线程+ js线程+ web线程+ uikit事件线程“

 */
- (IBAction)test3 {
    NSMutableSet<NSThread *> *set = [NSMutableSet set];
    for (int i=0; i < 1000; i++) {
        const char *label = [NSString stringWithFormat:@"label-:%d", i].UTF8String;
        NSLog(@"create:%s", label);
        dispatch_queue_t queue = dispatch_queue_create(label, DISPATCH_QUEUE_SERIAL);
        dispatch_async(queue, ^{
            NSThread *thread = [NSThread currentThread];
            [set addObject:[NSThread currentThread]];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                static NSInteger lastCount = 0;
                if (set.count <= lastCount) {
                    return;
                }
                lastCount = set.count;
                NSLog(@"begin:%@", thread);
                NSLog(@"GCD threads count量:%lu",(unsigned long)set.count);
                [self printThreadCount];
            });
            
            NSDate *date = [NSDate dateWithTimeIntervalSinceNow:10];
            long i=0;
            while ([date compare:[NSDate date]]) {
                i++;
            }
            [set removeObject:thread];
            NSLog(@"end:%@", thread);
        });
    }
}

- (IBAction)test4 {
    NSMutableSet<NSThread *> *set = [NSMutableSet set];
    for (int i=0; i < 10000; i++) {
        const char *label = [NSString stringWithFormat:@"label-:%d", i].UTF8String;
        NSLog(@"create:%s", label);
        dispatch_queue_t queue = dispatch_queue_create(label, DISPATCH_QUEUE_SERIAL);
        dispatch_async(queue, ^{
            NSThread *thread = [NSThread currentThread];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [set addObject:thread];
                static NSInteger lastCount = 0;
                if (set.count <= lastCount) {
                    return;
                }
                lastCount = set.count;
                NSLog(@"begin:%@", thread);
                NSLog(@"GCD threads count:%lu",(unsigned long)set.count);
                [self printThreadCount];
            });
            
            [NSThread sleepForTimeInterval:10];
            dispatch_async(dispatch_get_main_queue(), ^{
                [set removeObject:thread];
                NSLog(@"end:%@", thread);
            });
        });
    }
}

- (IBAction)test5 {
    __block int index = 0;
    
    // one concurrent  queue test
    dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
    for (int i = 0; i < 1000; ++i) {
        dispatch_async(queue, ^{
            id name = nil;
            @synchronized (self) {
                name = [NSString stringWithFormat:@"gcd-limit-test-global-concurrent-%d", index];
                index += 1;
            }
            NSThread.currentThread.name = name;
            NSLog(@"%@", name);
            sleep(100000);
        });
    }
}

- (IBAction)test6 {
    __block int index = 0;
    
    // some concurrent queues test
    for (int i = 0; i < 1000; ++i) {
        char buffer[256] = {};
        sprintf(buffer, "gcd-limit-test-concurrent-%d", i);
        dispatch_queue_t queue = dispatch_queue_create(buffer, DISPATCH_QUEUE_CONCURRENT);
        dispatch_async(queue, ^{
            id name = nil;
            @synchronized (self) {
                name = [NSString stringWithFormat:@"gcd-limit-test-concurrent-%d", index];
                index += 1;
            }
            NSThread.currentThread.name = name;
            NSLog(@"%@", name);
            sleep(100000);
        });
    }
}

- (IBAction)test7 {
    __block int index = 0;
    
    // some serial queues test
    for (int i = 0; i < 1000; ++i) {
        char buffer[256] = {};
        sprintf(buffer, "gcd-limit-test-%d", i);
        dispatch_queue_t queue = dispatch_queue_create(buffer, 0);
        dispatch_async(queue, ^{
            id name = nil;
            @synchronized (self) {
                name = [NSString stringWithFormat:@"gcd-limit-test-%d", index];
                index += 1;
            }
            NSThread.currentThread.name = name;
            NSLog(@"%@", name);
            sleep(100000);
        });
    }
}
@end
