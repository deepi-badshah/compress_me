import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:collection/collection.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Image Compression',
      theme: ThemeData(primarySwatch: Colors.amber),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? _selectedImage;
  double? _compressionRatio;
  String? _compressedImagePath;
  String? compressedBytes;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(source: ImageSource.gallery);
    if (pickedImage == null) return; // Add this null check

    setState(() {
      _selectedImage = File(pickedImage.path);
      _compressionRatio = 0.0;
      _compressedImagePath = null;
    });
  }

  Future<void> _compressImage() async {
    if (_selectedImage == null) return;

    final bytes = await _selectedImage!.readAsBytes();
    // if (bytes.isEmpty) {
    //   print('Error compressing image: Empty bytes');
    //   return;
    // }

    final compressedBytes = compressImage(bytes);
    if (compressedBytes == null) {
      print('Error compressing image: Null compressed bytes');
      return;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final compressedImageFile = File('${appDir.path}/compressed_image.jpg');
    try {
      await compressedImageFile.writeAsBytes(compressedBytes);
    } catch (e, stackTrace) {
      print('Error writing compressed image file: $e');
      print('Stack Trace: $stackTrace');
      return;
    }

    final originalSize = _selectedImage!.lengthSync();
    final compressedSize = compressedImageFile.lengthSync();

    setState(() {
      _compressedImagePath = compressedImageFile.path;
    });
  }

  List<int> compressImage(List<int> bytes) {
    // Count the frequency of each byte
    final frequencyMap = _countFrequency(bytes);
    // print('Frequency Map: $frequencyMap');

    // Build a priority queue of Huffman nodes
    final priorityQueue = HeapPriorityQueue<HuffmanNode>();
    for (final entry in frequencyMap.entries) {
      final node = HuffmanNode(entry.value);
      priorityQueue.add(node);
    }

    // Build the Huffman tree
    while (priorityQueue.length > 1) {
      final node1 = priorityQueue.removeFirst();
      final node2 = priorityQueue.removeFirst();
      final newNode = HuffmanNode(node1.frequency + node2.frequency);
      newNode.left = node1;
      newNode.right = node2;
      priorityQueue.add(newNode);
    }

    final huffmanTree = priorityQueue.first;

    // Generate the encoding table
    final encodingTable = <int, List<int>>{};
    _generateEncodingTable(huffmanTree, [], encodingTable);
    // print('Encoding Table: $encodingTable');

    // Encode the byte data
    final encodedData = <int>[];
    for (final byte in bytes) {
      final encoding = encodingTable[byte];
      // print(byte.toString() + " : ");
      if (encoding != null) {
        encodedData.addAll(encoding);
      } else {
        // print('Error compressing image: Encoding not found for byte $byte');
        // return [];
      }
    }
    // print(encodedData.toList());
    return encodedData;
  }

  void _generateEncodingTable(HuffmanNode node, List<int> currentEncoding,
      Map<int, List<int>> encodingTable) {
    if (node.left == null && node.right == null) {
      // Leaf node reached, add the current encoding to the table
      encodingTable[node.frequency] = currentEncoding.toList();
      // print(encodingTable[node.frequency]);
      return;
    }

    if (node.left != null) {
      currentEncoding.add(0);
      _generateEncodingTable(node.left!, currentEncoding, encodingTable);
      currentEncoding.removeLast();
    }

    if (node.right != null) {
      currentEncoding.add(1);
      _generateEncodingTable(node.right!, currentEncoding, encodingTable);
      currentEncoding.removeLast();
    }
  }

  Map<int, int> _countFrequency(List<int> bytes) {
    Map<int, int> frequencyMap = {};
    // var count = 0;
    // Initialize the frequency map with all possible byte values
    for (int i = 0; i < 256; i++) {
      frequencyMap[i] = 0;
    }

    for (final byte in bytes) {
      // count++;
      if (frequencyMap.containsKey(byte)) {
        frequencyMap[byte] = frequencyMap[byte]! + 1;
      } else {
        frequencyMap[byte] = 1;
      }
    }
    // print("frequency map generated" + count.toString());
    return frequencyMap;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Center(child: Text('Compress Me!'))),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_selectedImage != null)
                Image.file(_selectedImage!)
              else
                Text('No image selected.'),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _pickImage,
                child: Text('Select Image'),
              ),
              ElevatedButton(
                onPressed: _compressImage,
                child: Text('Compress Image'),
              ),
              if (_compressionRatio != null && _compressedImagePath != null)
                Column(
                  children: [
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        final originalFile = _selectedImage!;
                        final compressedFile = File(_compressedImagePath!);
                        final archive = Archive()
                          ..addFile(ArchiveFile(
                            originalFile.path,
                            originalFile.lengthSync(),
                            Uint8List.fromList(originalFile.readAsBytesSync()),
                          ))
                          ..addFile(ArchiveFile(
                            compressedFile.path,
                            compressedFile.lengthSync(),
                            Uint8List.fromList(
                                compressedFile.readAsBytesSync()),
                          ));

                        final encoder = ZipEncoder();
                        final compressedZipPath = '${originalFile.path}.zip';
                        final compressedZipFile = File(compressedZipPath);
                        await compressedZipFile
                            .writeAsBytes(encoder.encode(archive)!);

                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              'Compressed image downloaded: $compressedZipPath'),
                        ));
                      },
                      child: Text('Download Compressed Image'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class HuffmanNode implements Comparable<HuffmanNode> {
  final int frequency;
  HuffmanNode? left;
  HuffmanNode? right;

  HuffmanNode(this.frequency);

  @override
  int compareTo(HuffmanNode other) {
    return frequency - other.frequency;
  }
}
