import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../models/accounting_entry.dart';
import '../services/accounting_service.dart';
import '../services/auth_service.dart';

class AddEntryScreen extends StatefulWidget {
  final AccountingEntry? entry;

  const AddEntryScreen({super.key, this.entry});

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.entry != null) {
      _nameController.text = widget.entry!.name;
      _phoneController.text = widget.entry!.phone;
    }
  }

  Future<void> _pickContact() async {
    try {
      // openExternalPick uses an intent-based picker — no permission needed
      final contact = await FlutterContacts.openExternalPick();
      if (contact == null || !mounted) return;

      // Try to get full contact details (needs READ_CONTACTS permission)
      if (await FlutterContacts.requestPermission()) {
        final fullContact = await FlutterContacts.getContact(contact.id, withProperties: true);
        if (fullContact != null && mounted) {
          setState(() {
            if (_nameController.text.isEmpty) {
              _nameController.text = fullContact.displayName;
            }
            if (fullContact.phones.isNotEmpty) {
              _phoneController.text = fullContact.phones.first.number;
            }
          });
          return;
        }
      }

      // Fallback: use basic info from the picker if permission was denied
      if (mounted) {
        setState(() {
          if (_nameController.text.isEmpty) {
            _nameController.text = contact.displayName;
          }
          if (contact.phones.isNotEmpty) {
            _phoneController.text = contact.phones.first.number;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking contact: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.entry != null;
    
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                Text(
                  isEditing ? 'Edit Customer' : 'Add Customer',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (isEditing)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Customer'),
                          content: const Text('Are you sure you want to delete this customer?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      
                      if (confirm == true && context.mounted) {
                        final authService = Provider.of<AuthService>(context, listen: false);
                        await Provider.of<AccountingService>(context, listen: false)
                            .deleteEntry(widget.entry!.id!, authService.userId!);
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Customer name',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.person_outline, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                hintText: 'Contact number',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.phone_outlined, color: Colors.grey),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.contacts_outlined, color: Colors.blue),
                  onPressed: _pickContact,
                  tooltip: 'Pick from contacts',
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill all fields')),
                    );
                    return;
                  }

                  final authService = Provider.of<AuthService>(context, listen: false);
                  final accountingService = Provider.of<AccountingService>(context, listen: false);

                  final entry = AccountingEntry(
                    id: widget.entry?.id,
                    userId: authService.userId!,
                    name: _nameController.text,
                    phone: _phoneController.text,
                    advanceAmount: widget.entry?.advanceAmount ?? 0.0,
                    creditAmount: widget.entry?.creditAmount ?? 0.0,
                    debitAmount: widget.entry?.debitAmount ?? 0.0,
                    date: widget.entry?.date ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
                    imagePath: widget.entry?.imagePath,
                  );

                  if (isEditing) {
                    await accountingService.updateEntry(entry);
                  } else {
                    await accountingService.addEntry(entry);
                  }

                  if (context.mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[900],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  isEditing ? 'Update' : 'Save',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
