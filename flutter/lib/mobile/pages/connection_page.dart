import 'dart:async';
import 'dart:convert';

import 'package:auto_size_text_field/auto_size_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/common/widgets/connection_page_title.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:flutter_hbb/models/peer_model.dart';

import '../../common.dart';
import '../../common/widgets/peer_tab_page.dart';
import '../../common/widgets/autocomplete.dart';
import '../../consts.dart';
import '../../models/model.dart';
import '../../models/platform_model.dart';
import 'home_page.dart';

/// Connection page for connecting to a remote peer.
class ConnectionPage extends StatefulWidget implements PageShape {
  ConnectionPage({Key? key, required this.appBarActions}) : super(key: key);

  @override
  final icon = const Icon(Icons.connected_tv);

  @override
  final title = translate("Connection");

  @override
  final List<Widget> appBarActions;

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

/// State for the connection page.
class _ConnectionPageState extends State<ConnectionPage> {
  /// Controller for the id input bar.
  final _idController = IDTextEditingController();
  final RxBool _idEmpty = true.obs;

  final FocusNode _idFocusNode = FocusNode();
  final TextEditingController _idEditingController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberPassword = false;
  int _accessMethod = 0;
  final TextEditingController _codeController = TextEditingController();
  String _credentialEndpoint = '';

  final AllPeersLoader _allPeersLoader = AllPeersLoader();

  StreamSubscription? _uniLinksSubscription;

  // https://github.com/flutter/flutter/issues/157244
  Iterable<Peer> _autocompleteOpts = [];

  _ConnectionPageState() {
    if (!isWeb) _uniLinksSubscription = listenUniLinks();
    _idController.addListener(() {
      _idEmpty.value = _idController.text.isEmpty;
      final endpoint = _idController.id;
      if (_credentialEndpoint != endpoint && _rememberPassword) {
        if (mounted) {
          setState(() => _rememberPassword = false);
        } else {
          _rememberPassword = false;
        }
      }
      _credentialEndpoint = endpoint;
    });
    Get.put<IDTextEditingController>(_idController);
  }

  @override
  void initState() {
    super.initState();
    _allPeersLoader.init(setState);
    _idFocusNode.addListener(onFocusChanged);
    if (_idController.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final lastRemoteId = await bind.mainGetLastRemoteId();
        if (lastRemoteId != _idController.id) {
          setState(() {
            _idController.id = lastRemoteId;
          });
        }
      });
    }
    Get.put<TextEditingController>(_idEditingController);
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<FfiModel>(context);
    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildListDelegate([_buildRemoteIDTextField()]),
        ),
        SliverFillRemaining(hasScrollBody: true, child: PeerTabPage()),
      ],
    ).marginOnly(top: 2, left: 10, right: 10);
  }

  /// Callback for the connect button.
  /// Connects to the selected peer.
  Future<void> onConnect({
    bool isFileTransfer = false,
    bool isViewCamera = false,
    bool isTerminal = false,
  }) async {
    final endpoint = _idController.id;
    final password = _passwordController.text;
    final code = _codeController.text.trim();
    if (_accessMethod == 1 && !RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      showToast(translate('Enter a 6-digit temporary code'));
      return;
    }
    if (endpoint.isEmpty) {
      showToast(
        translate('Local Address'),
      );
      return;
    }
    await connect(
      context,
      endpoint,
      isFileTransfer: isFileTransfer,
      isViewCamera: isViewCamera,
      isTerminal: isTerminal,
      password: _accessMethod != 0
          ? jsonEncode({'lan_version': 1, 'access_method': _accessMethod,
              'temporary_code': _accessMethod == 1 ? code : ''})
          : password.isEmpty
          ? null
          : jsonEncode({
              'lan_version': 1,
              'username': '',
              'password': password,
              'remember': _rememberPassword,
            }),
    );
    _passwordController.clear();
    _codeController.clear();
    if (mounted) setState(() => _rememberPassword = false);
  }

  void onFocusChanged() {
    _idEmpty.value = _idEditingController.text.isEmpty;
    if (_idFocusNode.hasFocus) {
      if (_allPeersLoader.needLoad) {
        _allPeersLoader.getAllPeers();
      }

      final textLength = _idEditingController.value.text.length;
      // Select all to facilitate removing text, just following the behavior of address input of chrome.
      _idEditingController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: textLength,
      );
    }
  }

  /// UI for the remote endpoint field.
  /// Search for a peer and connect to it if the id exists.
  Widget _buildRemoteIDTextField() {
    final availableWidth = MediaQuery.sizeOf(context).width;
    final compact = availableWidth < 360;
    final w = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Ink(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.all(Radius.circular(13)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16),
                  child: RawAutocomplete<Peer>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text == '') {
                        _autocompleteOpts = const Iterable<Peer>.empty();
                      } else if (_allPeersLoader.peers.isEmpty &&
                          !_allPeersLoader.isPeersLoaded) {
                        Peer emptyPeer = Peer(
                          id: '',
                          username: '',
                          hostname: '',
                          alias: '',
                          platform: '',
                          fingerprint: '',
                          rdpPort: '',
                          rdpUsername: '',
                        );
                        _autocompleteOpts = [emptyPeer];
                      } else {
                        String textWithoutSpaces =
                            textEditingValue.text.replaceAll(" ", "");
                        if (int.tryParse(textWithoutSpaces) != null) {
                          textEditingValue = TextEditingValue(
                            text: textWithoutSpaces,
                            selection: textEditingValue.selection,
                          );
                        }
                        String textToFind = textEditingValue.text.toLowerCase();

                        _autocompleteOpts = _allPeersLoader.peers
                            .where(
                              (peer) =>
                                  peer.id.toLowerCase().contains(textToFind) ||
                                  peer.username.toLowerCase().contains(
                                        textToFind,
                                      ) ||
                                  peer.hostname.toLowerCase().contains(
                                        textToFind,
                                      ) ||
                                  peer.alias.toLowerCase().contains(textToFind),
                            )
                            .toList();
                      }
                      return _autocompleteOpts;
                    },
                    focusNode: _idFocusNode,
                    textEditingController: _idEditingController,
                    fieldViewBuilder: (
                      BuildContext context,
                      TextEditingController fieldTextEditingController,
                      FocusNode fieldFocusNode,
                      VoidCallback onFieldSubmitted,
                    ) {
                      updateTextAndPreserveSelection(
                        fieldTextEditingController,
                        _idController.text,
                      );
                      return AutoSizeTextField(
                        controller: fieldTextEditingController,
                        focusNode: fieldFocusNode,
                        minFontSize: 18,
                        autocorrect: false,
                        enableSuggestions: false,
                        keyboardType: TextInputType.visiblePassword,
                        // keyboardType: TextInputType.number,
                        onChanged: (String text) {
                          _idController.id = text;
                        },
                        style: const TextStyle(
                          fontFamily: 'WorkSans',
                          fontWeight: FontWeight.bold,
                          fontSize: 30,
                          color: MyTheme.idColor,
                        ),
                        decoration: InputDecoration(
                          labelText: '${translate('Local Address')} (IP / DNS)',
                          border: InputBorder.none,
                          helperStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: MyTheme.darkGray,
                          ),
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            letterSpacing: 0.2,
                            color: MyTheme.darkGray,
                          ),
                        ),
                        inputFormatters: [IDTextInputFormatter()],
                        onSubmitted: (_) {
                          onConnect();
                        },
                      );
                    },
                    onSelected: (option) {
                      setState(() {
                        _idController.id = option.id;
                        FocusScope.of(context).unfocus();
                      });
                    },
                    optionsViewBuilder: (
                      BuildContext context,
                      AutocompleteOnSelected<Peer> onSelected,
                      Iterable<Peer> options,
                    ) {
                      options = _autocompleteOpts;
                      double maxHeight = options.length * 50;
                      if (options.length == 1) {
                        maxHeight = 52;
                      } else if (options.length == 3) {
                        maxHeight = 146;
                      } else if (options.length == 4) {
                        maxHeight = 193;
                      }
                      maxHeight = maxHeight.clamp(0, 200);
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 5,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Material(
                              elevation: 4,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: maxHeight,
                                  maxWidth:
                                      (availableWidth - 24).clamp(200, 320),
                                ),
                                child: _allPeersLoader.peers.isEmpty &&
                                        !_allPeersLoader.isPeersLoaded
                                    ? Container(
                                        height: 80,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    : ListView(
                                        padding: EdgeInsets.only(top: 5),
                                        children: options
                                            .map(
                                              (peer) => AutocompletePeerTile(
                                                onSelect: () =>
                                                    onSelected(peer),
                                                peer: peer,
                                              ),
                                            )
                                            .toList(),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Obx(
                () => Offstage(
                  offstage: _idEmpty.value,
                  child: IconButton(
                    onPressed: () {
                      setState(() {
                        _idController.clear();
                      });
                    },
                    icon: Icon(Icons.clear, color: MyTheme.darkGray),
                  ),
                ),
              ),
              SizedBox(
                width: compact ? 48 : 60,
                height: compact ? 48 : 60,
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_forward,
                    color: MyTheme.darkGray,
                    size: compact ? 34 : 45,
                  ),
                  onPressed: onConnect,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final child = Column(
      children: [
        if (isWebDesktop)
          getConnectionPageTitle(
            context,
            true,
          ).marginOnly(bottom: 10, top: 15, left: 12),
        w,
        if (isAndroid)
          DropdownButtonFormField<int>(
            value: _accessMethod,
            decoration: InputDecoration(labelText: translate('Access method')),
            items: [
              DropdownMenuItem(value: 0, child: Text(translate('Password / saved password'))),
              DropdownMenuItem(value: 1, child: Text(translate('Temporary code'))),
              DropdownMenuItem(value: 2, child: Text(translate('Manual approval'))),
            ],
            onChanged: (value) => setState(() {
              _accessMethod = value ?? 0;
              _rememberPassword = false;
              _passwordController.clear();
              _codeController.clear();
            }),
          ),
        if (_accessMethod == 1)
          TextField(controller: _codeController, keyboardType: TextInputType.number,
            autocorrect: false, enableSuggestions: false, maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: translate('Receiver code (6 digits)')),
            onSubmitted: (_) => onConnect()),
        if (_accessMethod == 2)
          Padding(padding: const EdgeInsets.all(8), child: Text(translate('A request appears on the receiver. Control starts only after acceptance.'))),
        if (_accessMethod == 0) TextField(
          controller: _passwordController,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: translate('Password'),
            prefixIcon: const Icon(Icons.lock_outline),
          ),
          onSubmitted: (_) => onConnect(),
        ).marginSymmetric(horizontal: 4, vertical: 4),
        if (isAndroid && _accessMethod == 0)
          CheckboxListTile(
            value: _rememberPassword,
            onChanged: (value) => setState(() => _rememberPassword = value == true),
            dense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 4),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(translate('Remember password')),
            subtitle: Text(translate('Saved for this verified device only after successful login')),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final singleColumn = constraints.maxWidth < 340;
            final buttonWidth = singleColumn
                ? constraints.maxWidth
                : (constraints.maxWidth - 8) / 2;
            Widget action(
                IconData icon, String label, VoidCallback onPressed) {
              return SizedBox(
                width: buttonWidth,
                child: TextButton.icon(
                  onPressed: onPressed,
                  icon: Icon(icon),
                  label: Text(translate(label),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              );
            }

            return Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                action(Icons.desktop_windows_outlined, 'Connect',
                    () => onConnect()),
                action(Icons.folder_outlined, 'Transfer file',
                    () => onConnect(isFileTransfer: true)),
                action(Icons.terminal_outlined, 'Terminal',
                    () => onConnect(isTerminal: true)),
              ],
            );
          },
        ),
      ],
    );
    return Align(
      alignment: Alignment.topCenter,
      child: Container(constraints: kMobilePageConstraints, child: child),
    );
  }

  @override
  void dispose() {
    _uniLinksSubscription?.cancel();
    _idController.dispose();
    _idFocusNode.removeListener(onFocusChanged);
    _allPeersLoader.clear();
    _idFocusNode.dispose();
    _idEditingController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    if (Get.isRegistered<IDTextEditingController>()) {
      Get.delete<IDTextEditingController>();
    }
    if (Get.isRegistered<TextEditingController>()) {
      Get.delete<TextEditingController>();
    }
    super.dispose();
  }
}
