import 'package:flutter/material.dart';

class ManagerOrdersList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Orders List'),
        centerTitle: true,
      ),
      body: ListView.builder(
        itemCount: 10, // Replace with the actual number of orders
        itemBuilder: (context, index) {
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              leading: Icon(Icons.receipt_long),
              title: Text('Order #${index + 1}'),
              subtitle: Text('Details of the order go here'),
              trailing: Icon(Icons.arrow_forward),
              onTap: () {
                // Navigate to order details screen
              },
            ),
          );
        },
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: ManagerOrdersList(),
  ));
}