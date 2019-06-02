import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:outline_material_icons/outline_material_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../services/services.dart';
import '../shared/shared.dart';
import 'pages.dart';

class TabViewPage extends StatefulWidget {
  List<Connection> connections = [];
  final String jsonFileName;
  final bool isFavorites;

  Directory dir;
  File jsonFile;
  bool jsonFileExists = false;

  TabViewPage(this.jsonFileName, this.isFavorites);

  List<Connection> getConnectionsFromJson() {
    if (!jsonFileExists) return null;
    List<dynamic> jsonContent = json.decode(jsonFile.readAsStringSync());
    var jsonContent1 = List<Map<String, dynamic>>.from(jsonContent);
    var connections = List<Connection>(jsonContent.length);
    for (int i = 0; i < jsonContent.length; i++) {
      connections[i] = Connection.fromMap(jsonContent1[i]);
    }
    return connections;
  }

  void setConnectionsFromJson() {
    connections = getConnectionsFromJson();
  }

  File createJsonFile(Connection connection) {
    File file;
    file = jsonFile;
    file.createSync();
    jsonFileExists = true;
    file.writeAsStringSync(json.encode([connection.toMap()]));
    return file;
  }

  /// insert a new connection at a given index
  void insertToJson(int index, Connection connection) {
    if (jsonFileExists && jsonFile.readAsStringSync() != "") {
      List<Connection> list = [];
      list.addAll(getConnectionsFromJson());
      list.insert(index, connection);
      List<Map<String, String>> mapList = [];
      list.forEach((v) {
        mapList.add(v.toMap());
      });
      jsonFile.writeAsStringSync(json.encode(mapList));
    } else {
      createJsonFile(connection);
    }
  }

  /// insert a new connection at index 0
  void addToJson(Connection connection) {
    insertToJson(0, connection);
  }

  /// remove a connection at a given index
  void removeFromJsonAt(int index) {
    List<Connection> list = [];
    list.addAll(getConnectionsFromJson());
    list.removeAt(index);
    List<Map<String, String>> mapList = [];
    list.forEach((v) {
      mapList.add(v.toMap());
    });
    jsonFile.writeAsStringSync(json.encode(mapList));
  }

  @override
  _TabViewPageState createState() => _TabViewPageState();
}

class _TabViewPageState extends State<TabViewPage> {
  String _getSubtitle(int index) {
    String _output = "";
    bool _addressIsInOutput = false;
    if (index < widget.connections.length) {
      if (widget.connections[index].name != null) {
        _output += "Address: " + widget.connections[index].address;
        _addressIsInOutput = true;
      }
      if (widget.connections[index].port != "") {
        if (_addressIsInOutput) {
          _output += ", ";
        }
        _output += "Port: " + widget.connections[index].port;
      } else {
        if (_addressIsInOutput) {
          _output += ", ";
        }
        _output += "Port: 22";
      }
      if (widget.connections[index].username != "") {
        _output += ", Username: " + widget.connections[index].username;
      }
      if (widget.connections[index].path != "") {
        _output += ", Path: " + widget.connections[index].path;
      }
    }
    return _output;
  }

  List<GlobalKey> _reorderableKeys;

  void _addKeys() {
    setState(() => _reorderableKeys = []);
    int itemCount = widget.connections.length > 0 ? widget.connections.length : 1;
    for (int i = 0; i < itemCount; i++) {
      setState(() => _reorderableKeys.add(GlobalKey()));
    }
  }

  List<Widget> _getWidgetList() {
    _addKeys();
    List<Widget> widgets = [];
    int itemCount = widget.connections.length > 0 ? widget.connections.length : 1;
    for (int index = 0; index < itemCount; index++) {
      widgets.add(
        Container(
          key: _reorderableKeys[index],
          child: widget.connections.length > 0
              ? ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  title: widget.connections[index].name != "" && widget.connections[index].name != "-"
                      ? Text(widget.connections[index].name)
                      : Text(widget.connections[index].address),
                  subtitle: Text(_getSubtitle(index)),
                  trailing: IconButton(
                    icon: Icon(
                      OMIcons.edit,
                      color: Theme.of(context).accentColor,
                    ),
                    onPressed: () {
                      ConnectionDialog(
                        context: context,
                        index: index,
                        page: widget.isFavorites ? "favorites" : "recentlyAdded",
                        primaryButtonIconData: widget.isFavorites ? OMIcons.edit : Icons.star_border,
                        primaryButtonLabel: widget.isFavorites ? "Edit" : "Add to favorites",
                        primaryButtonOnPressed: () {
                          if (widget.isFavorites) {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditConnectionPage(index: index),
                              ),
                            );
                          } else {
                            HomePage.favoritesPage.addToJson(widget.connections[index]);
                            HomePage.favoritesPage.setConnectionsFromJson();
                            Navigator.pop(context);
                          }
                        },
                        hasSecondaryButton: true,
                        secondaryButtonIconData: OMIcons.delete,
                        secondaryButtonLabel: "Delete",
                        secondaryButtonOnPressed: () {
                          widget.removeFromJsonAt(index);
                          setState(() {
                            widget.setConnectionsFromJson();
                          });
                          Navigator.pop(context);
                        },
                      ).show();
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ConnectionPage(
                              Connection(
                                address: widget.connections[index].address,
                                port: widget.connections[index].port,
                                username: widget.connections[index].username,
                                passwordOrKey: widget.connections[index].passwordOrKey,
                                path: widget.connections[index].path,
                              ),
                            ),
                      ),
                    );
                    Provider.of<ConnectionModel>(context).currentConnection = null;
                    Future.delayed(Duration(milliseconds: 50)).then((_) {
                      ConnectionMethods.connect(context, Provider.of<ConnectionModel>(context), ConnectionPage.connection);
                    });
                  },
                )
              : Padding(
                  padding: EdgeInsets.only(top: 30.0),
                  child: Opacity(
                    opacity: .7,
                    child: Text(
                      "No favorites",
                      style: TextStyle(fontSize: 16.0),
                    ),
                  ),
                ),
        ),
      );
    }
    return widgets;
  }

  @override
  void initState() {
    (Platform.isIOS ? getApplicationSupportDirectory() : getApplicationDocumentsDirectory()).then((Directory dir) {
      setState(() {
        widget.dir = dir;
        widget.jsonFile = File(widget.dir.path + "/" + widget.jsonFileName);
        widget.jsonFileExists = widget.jsonFile.existsSync();
        if (widget.jsonFileExists) {
          widget.connections = [];
          widget.connections.addAll(widget.getConnectionsFromJson());
        }
      });
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: ReorderableListView(
        padding: EdgeInsets.only(top: 10.0),
        children: _getWidgetList(),
        onReorder: (int a, int b) {
          var temp = widget.connections[a];
          setState(() {
            widget.removeFromJsonAt(a);
            widget.insertToJson(b - (a > b ? 0 : 1), temp);
            widget.setConnectionsFromJson();
          });
        },
      ),
    );
  }
}
