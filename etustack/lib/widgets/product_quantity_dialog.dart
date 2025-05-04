import 'package:flutter/material.dart';
import '../models/product.dart';
import '../utils/app_constants.dart';

class ProductQuantityDialog extends StatefulWidget {
  final Product product;

  const ProductQuantityDialog({
    Key? key,
    required this.product,
  }) : super(key: key);

  @override
  State<ProductQuantityDialog> createState() => _ProductQuantityDialogState();
}

class _ProductQuantityDialogState extends State<ProductQuantityDialog> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Product Found'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.product.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (widget.product.description != null)
              Text(
                widget.product.description!,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppConstants.secondaryTextColor,
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Price:'),
                Text(
                  '\$${widget.product.sellPrice?.toStringAsFixed(2) ?? 'N/A'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Available:'),
                Text(
                  '${widget.product.quantity}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: widget.product.quantity > 0
                        ? AppConstants.successColor
                        : AppConstants.errorColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (widget.product.quantity > 0) ...[
              const Text('Quantity:'),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: _quantity > 1
                        ? () {
                            setState(() {
                              _quantity--;
                            });
                          }
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$_quantity',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _quantity < widget.product.quantity
                        ? () {
                            setState(() {
                              _quantity++;
                            });
                          }
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total:'),
                  Text(
                    '\$${(widget.product.sellPrice ?? 0 * _quantity).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ] else
              const Text(
                'This product is out of stock',
                style: TextStyle(
                  color: AppConstants.errorColor,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        if (widget.product.quantity > 0)
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop({
                'add': true,
                'quantity': _quantity,
              });
            },
            child: const Text('Add to Cart'),
          ),
      ],
    );
  }
}
