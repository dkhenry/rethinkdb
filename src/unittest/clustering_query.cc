#include "unittest/gtest.hpp"

#include "clustering/immediate_consistency/branch/broadcaster.hpp"
#include "clustering/immediate_consistency/branch/listener.hpp"
#include "clustering/immediate_consistency/branch/replier.hpp"
#include "clustering/immediate_consistency/query/master.hpp"
#include "clustering/immediate_consistency/query/namespace_interface.hpp"
#include "rpc/mailbox/mailbox.hpp"
#include "unittest/clustering_utils.hpp"
#include "unittest/dummy_metadata_controller.hpp"
#include "unittest/dummy_protocol.hpp"
#include "unittest/unittest_utils.hpp"

namespace unittest {

namespace {

/* `let_stuff_happen()` delays for some time to let events occur */
void let_stuff_happen() {
    nap(1000);
}

}   /* anonymous namespace */

/* The `ReadWrite` test sends some reads and writes to some shards via a
`cluster_namespace_interface_t`. */

static void run_read_write_test() {

    /* Set up a cluster so mailboxes can be created */
    simple_mailbox_cluster_t cluster;

    /* Set up metadata meeting-places */
    branch_history_t<dummy_protocol_t> initial_branch_metadata;
    dummy_semilattice_controller_t<branch_history_t<dummy_protocol_t> > branch_history_controller(initial_branch_metadata);
    std::map<branch_id_t, broadcaster_business_card_t<dummy_protocol_t> > initial_broadcaster_directory;
    simple_directory_manager_t<std::map<branch_id_t, broadcaster_business_card_t<dummy_protocol_t> > >
        broadcaster_directory_controller(&cluster, initial_broadcaster_directory);

    /* Set up a branch */
    test_store_t initial_store;
    cond_t interruptor;
    boost::scoped_ptr<listener_t<dummy_protocol_t> > initial_listener;
    broadcaster_t<dummy_protocol_t> broadcaster(cluster.get_mailbox_manager(), broadcaster_directory_controller.get_root_view(), branch_history_controller.get_view(), &initial_store.store, &interruptor, &initial_listener);
    replier_t<dummy_protocol_t> initial_replier(initial_listener.get());

    /* Set up a metadata meeting-place for masters */
    std::map<master_id_t, master_business_card_t<dummy_protocol_t> > initial_master_metadata;
    simple_directory_manager_t<std::map<master_id_t, master_business_card_t<dummy_protocol_t> > > master_metadata_controller(&cluster, initial_master_metadata);

    /* Set up a master */
    master_t<dummy_protocol_t> master(cluster.get_mailbox_manager(), master_metadata_controller.get_root_view(), a_thru_z_region(), &broadcaster);

    /* Set up a namespace dispatcher */
    cluster_namespace_interface_t<dummy_protocol_t> namespace_interface(cluster.get_mailbox_manager(), master_metadata_controller.get_root_view());

    /* Send some writes to the namespace */
    order_source_t order_source;
    inserter_t inserter(
        boost::bind(&namespace_interface_t<dummy_protocol_t>::write, &namespace_interface, _1, _2, _3),
        &order_source);
    nap(100);
    inserter.stop();

    /* Now send some reads */
    for (std::map<std::string, std::string>::iterator it = inserter.values_inserted.begin();
            it != inserter.values_inserted.end(); it++) {
        dummy_protocol_t::read_t r;
        r.keys.keys.insert((*it).first);
        cond_t interruptor;
        dummy_protocol_t::read_response_t resp = namespace_interface.read(r, order_source.check_in("unittest"), &interruptor);
        EXPECT_EQ((*it).second, resp.values[(*it).first]);
    }
}

TEST(ClusteringNamespace, ReadWrite) {
    run_in_thread_pool(&run_read_write_test);
}

}   /* namespace unittest */
