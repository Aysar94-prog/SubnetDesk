import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/peer_tab_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../common.dart';
import '../peer_subnet_grouping.dart';
import '../../models/favorite_group_model.dart';
import '../../models/peer_model.dart';
import '../../models/platform_model.dart';
import 'peer_card.dart';
import 'responsive_layout.dart';

typedef PeerFilter = bool Function(Peer peer);
typedef PeerCardBuilder = Widget Function(Peer peer);

class PeerSortType {
  static const String endpoint = 'Endpoint';
  static const String remoteHost = 'Remote Host';
  static const String username = 'Username';
  static const String status = 'Status';
  static const String lastConnected = 'Last connection';

  static List<String> values = [
    PeerSortType.endpoint,
    PeerSortType.remoteHost,
    PeerSortType.username,
    PeerSortType.status,
    PeerSortType.lastConnected,
  ];
}

class LoadEvent {
  static const String recent = 'load_recent_peers';
  static const String favorite = 'load_fav_peers';
  static const String lan = 'load_lan_peers';
}

class PeersModelName {
  static const String recent = 'recent peer';
  static const String favorite = 'fav peer';
  static const String lan = 'discovered peer';
}

/// for peer search text, global obs value
final peerSearchText = "".obs;

/// for peer sort, global obs value
RxString? _peerSort;
RxString get peerSort {
  _peerSort ??= bind.getLocalFlutterOption(k: kOptionPeerSorting).obs;
  return _peerSort!;
}

// list for listener
RxList<RxString> get obslist => [peerSearchText, peerSort].obs;

final peerSearchTextController =
    TextEditingController(text: peerSearchText.value);

class _PeersView extends StatefulWidget {
  final Peers peers;
  final PeerFilter? peerFilter;
  final PeerCardBuilder peerCardBuilder;
  final PeerTabIndex peerTabIndex;

  const _PeersView(
      {required this.peers,
      required this.peerCardBuilder,
      required this.peerTabIndex,
      this.peerFilter,
      Key? key})
      : super(key: key);

  @override
  _PeersViewState createState() => _PeersViewState();
}

/// State for the peer widget.
class _PeersViewState extends State<_PeersView> {
  final HashMap<String, String> _emptyMessages = HashMap.from({
    LoadEvent.recent: 'empty_recent_tip',
    LoadEvent.favorite: 'empty_favorite_tip',
    LoadEvent.lan: 'empty_lan_tip',
  });
  final space = (isDesktop || isWebDesktop) ? 12.0 : 8.0;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // We should avoid too many rebuilds. MacOS(m1, 14.6.1) on Flutter 3.19.6.
    // Continious rebuilds of `ChangeNotifierProvider` will cause memory leak.
    // Simple demo can reproduce this issue.
    return ChangeNotifierProvider<Peers>.value(
      value: widget.peers,
      child: Consumer<Peers>(builder: (context, peers, child) {
        // Apply the tab filter before deciding emptiness, so a tab whose peers
        // are all filtered out (e.g. a Discovered list where every device is
        // offline) still shows the empty tip instead of a blank list.
        final visiblePeers = widget.peerFilter == null
            ? peers.peers
            : peers.peers.where(widget.peerFilter!).toList(growable: false);
        if (visiblePeers.isEmpty) {
          gFFI.peerTabModel.setCurrentTabCachedPeers([]);
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.sentiment_very_dissatisfied_rounded,
                  color: Theme.of(context).tabBarTheme.labelColor,
                  size: 40,
                ).paddingOnly(bottom: 10),
                Text(
                  translate(
                    _emptyMessages[widget.peers.loadEvent] ?? 'Empty',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).tabBarTheme.labelColor,
                  ),
                ),
              ],
            ),
          );
        } else {
          return _buildPeersView(peers);
        }
      }),
    );
  }

  Widget _buildPeersView(Peers peers) {
    final body = ObxValue<RxList>((filters) {
      return FutureBuilder<List<Peer>>(
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            var peers = snapshot.data!;
            if (peers.length > 1000) peers = peers.sublist(0, 1000);
            final groups = groupBySubnet<Peer>(peers, (peer) => peer.id);
            gFFI.peerTabModel.setCurrentTabCachedPeers(
                groups.expand((group) => group.items).toList());
            buildOnePeer(Peer peer, bool isPortrait) {
              final peerCard = widget.peerCardBuilder(peer);
              // `Provider.of<PeerTabModel>(context)` will causes infinete loop.
              // Because `gFFI.peerTabModel.setCurrentTabCachedPeers(peers)` will trigger `notifyListeners()`.
              //
              // No need to listen the currentTab change event.
              // Because the currentTab change event will trigger the peers change event,
              // and the peers change event will trigger _buildPeersView().
              return !isPortrait
                  ? Obx(() => peerCardUiType.value == PeerUiType.list
                      ? Container(height: 45, child: peerCard)
                      : peerCardUiType.value == PeerUiType.grid
                          ? SizedBox.expand(child: peerCard)
                          : SizedBox(width: 220, height: 42, child: peerCard))
                  : Container(child: peerCard);
            }

            // Each subnet gets a header followed by its own list/grid, so
            // devices on different subnets/VLANs are visually separated.
            List<Widget> groupedSlivers(Widget Function(List<Peer>) buildItems) =>
                [
                  for (var i = 0; i < groups.length; i++) ...[
                    SliverToBoxAdapter(
                        child: _buildSubnetHeader(context, groups[i], i == 0)),
                    buildItems(groups[i].items),
                  ],
                ];

            Widget peerList(List<Peer> items, bool isPortrait) => SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => buildOnePeer(items[index], isPortrait)
                        .marginOnly(
                            right: isPortrait ? 0 : space,
                            top: index == 0 ? 0 : space / 2,
                            bottom: space / 2),
                    childCount: items.length,
                  ),
                );

            // We should avoid too many rebuilds. Win10(Some machines) on Flutter 3.19.6.
            // Continious rebuilds of `ListView.builder` will cause memory leak.
            // Simple demo can reproduce this issue.
            final Widget child = Obx(() => shouldUseCompactPeerLayout(
                    isMobilePlatform: isMobile,
                    isWebMobile: isWeb && !isWebDesktop,
                    isPortrait: stateGlobal.isPortrait.isTrue)
                ? CustomScrollView(
                    slivers: groupedSlivers((items) => peerList(items, true)),
                  )
                : peerCardUiType.value == PeerUiType.list
                    ? CustomScrollView(
                        controller: _scrollController,
                        slivers:
                            groupedSlivers((items) => peerList(items, false)),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final columnCount =
                              ((constraints.maxWidth + space) / (220 + space))
                                  .floor()
                                  .clamp(1, 6)
                                  .toInt();
                          final cardWidth = (constraints.maxWidth -
                                  space * (columnCount - 1)) /
                              columnCount;
                          return CustomScrollView(
                            controller: _scrollController,
                            slivers: groupedSlivers((items) => SliverGrid(
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columnCount,
                                    mainAxisSpacing: space,
                                    crossAxisSpacing: space,
                                    childAspectRatio: cardWidth / 250,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) =>
                                        buildOnePeer(items[index], false),
                                    childCount: items.length,
                                  ),
                                )),
                          );
                        },
                      ));

            return child;
          } else {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        },
        future: matchPeers(filters[0].value, filters[1].value, peers.peers),
      );
    }, obslist);

    return body;
  }

  Widget _buildSubnetHeader(
      BuildContext context, SubnetGroup<Peer> group, bool isFirst) {
    final color = Theme.of(context).hintColor;
    return Padding(
      padding: EdgeInsets.only(
          top: isFirst ? 0 : space, bottom: space / 2, right: space),
      child: Row(
        children: [
          Icon(Icons.lan_outlined, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            group.label ?? translate('Other'),
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
          const SizedBox(width: 6),
          Text('(${group.items.length})', style: TextStyle(color: color)),
          const SizedBox(width: 10),
          const Expanded(child: Divider(height: 1)),
        ],
      ),
    );
  }

  Future<List<Peer>>? matchPeers(
      String searchText, String sortedBy, List<Peer> peers) async {
    if (widget.peerFilter != null) {
      peers = peers.where((peer) => widget.peerFilter!(peer)).toList();
    }

    // fallback to id sorting
    if (!PeerSortType.values.contains(sortedBy)) {
      sortedBy = PeerSortType.endpoint;
      bind.setLocalFlutterOption(
        k: kOptionPeerSorting,
        v: sortedBy,
      );
    }

    favoriteGroupModel.load();
    if (widget.peers.loadEvent != LoadEvent.recent || sortedBy == PeerSortType.lastConnected) {
      switch (sortedBy) {
        case PeerSortType.endpoint:
          peers.sort((p1, p2) => p1.getId().compareTo(p2.getId()));
          break;
        case PeerSortType.remoteHost:
          peers.sort((p1, p2) =>
              p1.hostname.toLowerCase().compareTo(p2.hostname.toLowerCase()));
          break;
        case PeerSortType.username:
          peers.sort((p1, p2) =>
              p1.username.toLowerCase().compareTo(p2.username.toLowerCase()));
          break;
        case PeerSortType.status:
          peers.sort((p1, p2) => p1.online == p2.online
              ? p1.getId().compareTo(p2.getId()) : p1.online ? -1 : 1);
          break;
        case PeerSortType.lastConnected:
          peers.sort((p1, p2) => p2.lastConnectedAt.compareTo(p1.lastConnectedAt));
          break;
      }
    }

    searchText = searchText.trim();
    if (searchText.isEmpty) {
      return peers;
    }
    searchText = searchText.toLowerCase();
    final matches = await Future.wait(
        peers.map((peer) async => await matchPeer(searchText, peer, widget.peerTabIndex) ||
            favoriteGroupModel.groups.any((group) =>
                favoriteGroupModel.groupIdForPeer(peer.id) == group.id &&
                group.name.toLowerCase().contains(searchText))));
    final filteredList = List<Peer>.empty(growable: true);
    for (var i = 0; i < peers.length; i++) {
      if (matches[i]) {
        filteredList.add(peers[i]);
      }
    }

    return filteredList;
  }
}

abstract class BasePeersView extends StatelessWidget {
  final PeerTabIndex peerTabIndex;
  final PeerFilter? peerFilter;
  final PeerCardBuilder peerCardBuilder;

  const BasePeersView({
    Key? key,
    required this.peerTabIndex,
    this.peerFilter,
    required this.peerCardBuilder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Peers peers;
    switch (peerTabIndex) {
      case PeerTabIndex.recent:
        peers = gFFI.recentPeersModel;
        break;
      case PeerTabIndex.fav:
        peers = gFFI.favoritePeersModel;
        break;
      case PeerTabIndex.lan:
        peers = gFFI.lanPeersModel;
        break;
    }
    return _PeersView(
        peers: peers,
        peerFilter: peerFilter,
        peerCardBuilder: peerCardBuilder,
        peerTabIndex: peerTabIndex);
  }
}

class RecentPeersView extends BasePeersView {
  RecentPeersView(
      {Key? key, EdgeInsets? menuPadding, ScrollController? scrollController})
      : super(
          key: key,
          peerTabIndex: PeerTabIndex.recent,
          peerCardBuilder: (Peer peer) => RecentPeerCard(
            peer: peer,
            menuPadding: menuPadding,
          ),
        );

  @override
  Widget build(BuildContext context) {
    final widget = super.build(context);
    bind.mainLoadRecentPeers();
    return widget;
  }
}

class FavoritePeersView extends BasePeersView {
  FavoritePeersView(
      {Key? key,
      EdgeInsets? menuPadding,
      ScrollController? scrollController,
      String? groupId})
      : super(
          key: key,
          peerTabIndex: PeerTabIndex.fav,
          peerFilter: groupId == null
              ? null
              : (Peer peer) => favoriteGroupModel.matches(peer.id, groupId),
          peerCardBuilder: (Peer peer) => FavoritePeerCard(
            peer: peer,
            menuPadding: menuPadding,
          ),
        );

  @override
  Widget build(BuildContext context) {
    final widget = super.build(context);
    bind.mainLoadFavPeers();
    return widget;
  }
}

class DiscoveredPeersView extends BasePeersView {
  DiscoveredPeersView(
      {Key? key, EdgeInsets? menuPadding, ScrollController? scrollController})
      : super(
          key: key,
          peerTabIndex: PeerTabIndex.lan,
          peerFilter: includeInDiscoveredList,
          peerCardBuilder: (Peer peer) => DiscoveredPeerCard(
            peer: peer,
            menuPadding: menuPadding,
          ),
        );

  @override
  Widget build(BuildContext context) {
    final widget = super.build(context);
    if (!isDesktop) {
      bind.mainLoadLanPeers();
      bind.mainDiscover();
    }
    return widget;
  }
}
