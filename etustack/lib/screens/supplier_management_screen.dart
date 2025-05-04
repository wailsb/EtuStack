import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../services/database_helper.dart';
import '../models/supplier.dart';
import '../utils/app_constants.dart';

class SupplierManagementScreen extends StatefulWidget {
  const SupplierManagementScreen({Key? key}) : super(key: key);

  @override
  State<SupplierManagementScreen> createState() => _SupplierManagementScreenState();
}

class _SupplierManagementScreenState extends State<SupplierManagementScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Supplier> _suppliers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final suppliers = await _dbHelper.getSuppliers();
      setState(() {
        _suppliers = suppliers;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading suppliers: $e'),
          backgroundColor: AppConstants.errorColor,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredSuppliers = _suppliers.where((supplier) {
      final searchLower = _searchQuery.toLowerCase();
      return supplier.name.toLowerCase().contains(searchLower) ||
          (supplier.company?.toLowerCase() ?? '').contains(searchLower) ||
          (supplier.description?.toLowerCase() ?? '').contains(searchLower) ||
          (supplier.phone?.toLowerCase() ?? '').contains(searchLower);
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search Suppliers',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredSuppliers.isEmpty
                    ? const Center(
                        child: Text('No suppliers found'),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadSuppliers,
                        child: ListView.builder(
                          itemCount: filteredSuppliers.length,
                          itemBuilder: (context, index) {
                            final supplier = filteredSuppliers[index];
                            return Slidable(
                              endActionPane: ActionPane(
                                motion: const ScrollMotion(),
                                children: [
                                  SlidableAction(
                                    onPressed: (context) {
                                      _editSupplier(supplier);
                                    },
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    icon: Icons.edit,
                                    label: 'Edit',
                                  ),
                                  SlidableAction(
                                    onPressed: (context) {
                                      _deleteSupplier(supplier);
                                    },
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    icon: Icons.delete,
                                    label: 'Delete',
                                  ),
                                ],
                              ),
                              child: Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppConstants.primaryColor,
                                    child: Text(
                                      supplier.name.substring(0, 1),
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  title: Text(supplier.name),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (supplier.company != null)
                                        Text('Company: ${supplier.company}'),
                                      if (supplier.phone != null)
                                        Text('Phone: ${supplier.phone}'),
                                    ],
                                  ),
                                  onTap: () {
                                    _viewSupplier(supplier);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSupplier,
        tooltip: 'Add Supplier',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _addSupplier() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupplierFormScreen(
          onSupplierSaved: _loadSuppliers,
        ),
      ),
    );
  }

  void _editSupplier(Supplier supplier) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupplierFormScreen(
          supplier: supplier,
          onSupplierSaved: _loadSuppliers,
        ),
      ),
    );
  }

  void _viewSupplier(Supplier supplier) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupplierDetailScreen(supplier: supplier),
      ),
    );
  }

  void _deleteSupplier(Supplier supplier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Supplier'),
        content: Text('Are you sure you want to delete ${supplier.name}?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await _dbHelper.deleteSupplier(supplier.id!);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Supplier deleted successfully'),
                    backgroundColor: AppConstants.successColor,
                  ),
                );
                _loadSuppliers();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting supplier: $e'),
                    backgroundColor: AppConstants.errorColor,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// Supplier Form Screen for adding and editing suppliers
class SupplierFormScreen extends StatefulWidget {
  final Supplier? supplier;
  final Function onSupplierSaved;

  const SupplierFormScreen({
    Key? key,
    this.supplier,
    required this.onSupplierSaved,
  }) : super(key: key);

  @override
  State<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends State<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.supplier != null) {
      _nameController.text = widget.supplier!.name;
      _companyController.text = widget.supplier!.company ?? '';
      _descriptionController.text = widget.supplier!.description ?? '';
      _phoneController.text = widget.supplier!.phone ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.supplier == null ? 'Add Supplier' : 'Edit Supplier'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Supplier Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a supplier name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _companyController,
                      decoration: const InputDecoration(
                        labelText: 'Company',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveSupplier,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: Text(
                        widget.supplier == null ? 'Add Supplier' : 'Update Supplier',
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _saveSupplier() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final supplier = Supplier(
          id: widget.supplier?.id,
          name: _nameController.text.trim(),
          company: _companyController.text.trim().isNotEmpty
              ? _companyController.text.trim()
              : null,
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          phone: _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
        );

        if (widget.supplier == null) {
          await _dbHelper.insertSupplier(supplier);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Supplier added successfully'),
              backgroundColor: AppConstants.successColor,
            ),
          );
        } else {
          await _dbHelper.updateSupplier(supplier);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Supplier updated successfully'),
              backgroundColor: AppConstants.successColor,
            ),
          );
        }

        widget.onSupplierSaved();
        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving supplier: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

// Supplier Detail Screen
class SupplierDetailScreen extends StatelessWidget {
  final Supplier supplier;

  const SupplierDetailScreen({
    Key? key,
    required this.supplier,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(supplier.name),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Supplier Information',
                      style: AppConstants.subheadingStyle,
                    ),
                    const Divider(),
                    _buildInfoRow('Name', supplier.name),
                    if (supplier.company != null)
                      _buildInfoRow('Company', supplier.company!),
                    if (supplier.description != null)
                      _buildInfoRow('Description', supplier.description!),
                    if (supplier.phone != null)
                      _buildInfoRow('Phone', supplier.phone!),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
