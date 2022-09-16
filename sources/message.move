address 0x2{
// ---------------------------message moduel----------------------
    module TxtMsg{
        use std::signer;
        use std::vector;
        use std::debug;
        use std::string;
        use std::error;

        const AVAILABLE:u64=1;
        const CLOSED:u64=2;
        const SOLD:u64=0;
        const EMPTY_RECEIVER:u64=1001;        
        const GROUP_NOT_EXISTS:u64=1002;
        const MESSAGE_NOT_EXISTS:u64=1005;
        const MESSAGES_NOT_EXISTS:u64=1006;
        const FRIEND_NOT_FOUND:u64=1007;
        const READ:u64=1;
        const UNREAD:u64=0;
        const TO_NOT_EXISTS:u64=1003;
        const NOT_FRIENDS:u64=1004;

        // holds message info
        struct Message has copy,drop,store{
            content:string::String,
            time_stamp:u64,
            sender:address,
            to_group:vector<Group>,
            to_single:vector<address>,
            status:u64,
        }

        // Resource Messages
        struct Messages has key,store{
            inbox:vector<Message>,
            sent:vector<Message>,
            friends:vector<address>,
            new_message_count:u64,
        }

        // Holds group info
        struct Group has store,drop,copy{
            id:u64,
            name:string::String,
            members:vector<address>,
            admins:vector<address>
        }

        // Resource holds Groups
        struct Groups has key,store{    
            groups_list:vector<Group>,
        }

        public entry fun init(account:&signer) {
            let msg=Messages{
                    inbox:vector::empty<Message>(),
                    sent:vector::empty<Message>(),
                    friends:vector::empty<address>(),
                    new_message_count:0,
            };
            move_to(account,msg);
        }

        // send message to mutilple addresses. 
        public entry fun send_message_addrs(account:&signer,content:string::String,msg_to:&vector<address>) acquires Messages{
            assert!(vector::length(msg_to)!=0,error::invalid_argument(EMPTY_RECEIVER));
            let addr=signer::address_of(account);
            // step1: add message to sender's sent
            if (!exists<Messages>(addr)){
                move_to(account,Messages{
                    inbox:vector::empty<Message>(),
                    sent:vector::empty<Message>(),
                    friends:vector::empty<address>(),
                    new_message_count:0,
                });
            };
            let msgs=borrow_global_mut<Messages>(addr);
            let sent=&mut msgs.sent;

            vector::push_back(sent,Message{
                content:content,
                time_stamp:1999923,
                sender:addr,
                to_group:vector::empty<Group>(),
                to_single:*msg_to,
                status:UNREAD,
            });

            // step2: add message to receivers' inbox
            let len=vector::length(msg_to);
            let i=0;
                //generate Message
            let msg=Message{
                content:content,
                time_stamp:198493,
                sender:addr,
                to_group:vector::empty<Group>(),
                to_single:vector::empty<address>(),
                status:UNREAD
            };

            while(i < len){
                    // copy one address in msg_to vector
                    let to=*vector::borrow(msg_to,i);                    
                    i=i+1;
                    // if address does not hold Messages, skip this address.
                    if(!exists<Messages>(to)) continue;
                    let msgs=borrow_global_mut<Messages>(to);
                    debug::print(msgs);
                    
                    // make sure sender is in friends list.
                    if (vector::contains(&msgs.friends,&addr)){

                        vector::push_back(&mut msgs.inbox,msg);
                         msgs.new_message_count=msgs.new_message_count+1;
                         }
                    else{
                        error::permission_denied(NOT_FRIENDS);
                        continue
                    };
            }
        }

        // send message to a group of addresses.
        public entry fun send_group_message (account:&signer,content:string::String,group_id:u64 ) acquires Messages, Groups{
            let addr=signer::address_of(account);
            assert!(exists<Groups>(addr),1003);
            let groups=borrow_global_mut<Groups>(addr);
            let len=vector::length(& groups.groups_list);
            assert!(len==0,1004);
            assert!( group_id > len,error::out_of_range(GROUP_NOT_EXISTS));
            let addrs=vector::borrow(& groups.groups_list,group_id);
            send_message_addrs(account,content,&addrs.members);
        }
        // only account owner could check his own messages.
        public entry fun check_new_messages(account:&signer) acquires Messages{
            let addr=signer::address_of(account);
            assert!(exists<Messages>(addr),MESSAGE_NOT_EXISTS);
            let msgs=borrow_global_mut<Messages>(addr);
            let new_msg_count=msgs.new_message_count;
            if (new_msg_count==0) return ;
            let inbox=&mut msgs.inbox;
            let len=vector::length(inbox);
            let i=0;
            while(i < new_msg_count){
                let msg=vector::borrow_mut(inbox,len-i-1);
                msg.status= READ;
                debug::print(msg);
                i=i+1;
            };
            msgs.new_message_count=0;
        }

        public entry fun check_new_msg_count(account:&signer):u64 acquires Messages{
            let addr=signer::address_of(account);
                assert!(exists<Messages>(addr),MESSAGE_NOT_EXISTS);
                let msgs=borrow_global_mut<Messages>(addr);
                msgs.new_message_count
        }
        // list all groups under owner's address
        public entry fun check_groups (account:&signer) acquires Groups{
            let addr=signer::address_of(account);
            assert!(exists<Groups>(addr),error::not_found(GROUP_NOT_EXISTS));
            let gps=borrow_global<Groups>(addr);
            let gps_list=& gps.groups_list;
            if (vector::length(gps_list)==0) debug::print(& string::utf8(b"no group found"));
            let len=vector::length(gps_list);
            let i=0;
            while(i < len){
                let gp=vector::borrow(gps_list,i);
                debug::print(gp);
                i=i+1;
            }

        }

        public entry fun add_friend(account:&signer,friend_addr:address) acquires Messages{
            let addr=signer::address_of(account);
            assert!(exists<Messages>(addr),MESSAGE_NOT_EXISTS);
            let msg=borrow_global_mut<Messages>(addr);
            vector::push_back(&mut msg.friends,friend_addr);
        }

        public entry fun remove_friend(account:&signer,friend_addr:&address) acquires Messages{
            let addr=signer::address_of(account);
            assert!(exists<Messages>(addr),MESSAGES_NOT_EXISTS);
            let msgs=borrow_global_mut<Messages>(addr);
            let friends= &mut msgs.friends;
            let (fri_exists,ind)=vector::index_of(friends,friend_addr);
            assert!(!fri_exists,error::not_found(FRIEND_NOT_FOUND));
            vector::remove(friends,ind);
        }

        // add new group, only available for its owner's account
        public fun add_group(account:&signer,members:&vector<address>,name:string::String):u64 acquires Groups{
            let addr=signer::address_of(account);
            if(!exists<Groups>(addr)){
                move_to(account,Groups{
                    groups_list: vector::empty<Group>(),
                    },
                 );
            };
            let groups=borrow_global_mut<Groups>(addr);
            let gps=&mut groups.groups_list;
            let len=vector::length(gps);
            let admins=&mut vector::empty<address>();
            vector::push_back(admins,addr);
            let group=Group{
                                        id:len,
                                        members:*members,
                                        admins:*admins,
                                        name:name,
                                    };
            vector::push_back(gps,group); 
            len
        }

 
    }

// ---------------------------test moduel----------------------

    module test{
            use 0x2::TxtMsg::send_message_addrs;
            use 0x2::TxtMsg::add_friend;
            use 0x2::TxtMsg::check_new_messages;
            use 0x2::TxtMsg::check_new_msg_count;
            use 0x2::TxtMsg::init;
            use std::vector;
            use std::string;
            use std::debug;

            #[test(_sender=@0x3,_add_sender=@0x3,receiver1=@0x4,_receiver1=@0x4,receiver2=@0x5,_receiver2=@0x5)]
            fun test_funs(_sender:&signer,_add_sender:address,receiver1:&signer,_receiver1:address,receiver2:&signer,_receiver2:address){
                // create address vector and stuff in
                let addrs=vector::empty<address>();
                vector::push_back(&mut addrs,_receiver1);
                vector::push_back(&mut addrs,_receiver2);
                let content=string::utf8(b"Hello, Blockchain");
                // Resource Messages could only be created by account
                init(receiver1);
                init(receiver2);
                // add friend
                add_friend(receiver1,_add_sender);
                add_friend(receiver2,_add_sender);
                send_message_addrs(_sender,content,&addrs);
                debug::print(&check_new_msg_count(receiver1));
                debug::print(&check_new_msg_count(receiver2));
                check_new_messages(receiver1);

            }
    }


}
