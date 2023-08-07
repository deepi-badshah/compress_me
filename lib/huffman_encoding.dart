import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';

class Node implements Comparable<Node> {
  late String data;
  late int freq;
  Node? left;
  Node? right;

  Node(String ch, int fr) {
    data = ch;
    freq = fr;
    left = null;
    right = null;
  }

  @override
  int compareTo(Node other) {
    return freq.compareTo(other.freq);
  }
}

class Solution {
  void traverse(Node? head, List<String> ans, [String output = '']) {
    if (head?.left == null && head?.right == null) {
      ans.add(output);
      return;
    }
    if (head?.left != null) traverse(head?.left, ans, output + '0');
    if (head?.right != null) traverse(head?.right, ans, output + '1');
  }

  List<String> huffmanCodes(String S, List<int> f, int N) {
    PriorityQueue<Node> pq = PriorityQueue<Node>();
    for (int i = 0; i < N; i++) {
      String str = S[i];
      Node temp = Node(str, f[i]);
      pq.add(temp);
    }
    while (pq.length != 1) {
      Node a = pq.removeFirst();
      Node b = pq.removeFirst();
      Node c = Node(a.data + b.data, a.freq + b.freq);
      pq.add(c);
      c.left = a;
      c.right = b;
    }
    Node? head = pq.first;
    List<String> ans = [];
    traverse(head, ans);
    return ans;
  }
}
