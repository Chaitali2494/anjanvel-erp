import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_widgets.dart';
import '../../data/booking_service.dart';
import '../../../guests/data/guest_service.dart';

class CreateBookingScreen extends ConsumerStatefulWidget {
  const CreateBookingScreen({super.key});

  @override
  ConsumerState<CreateBookingScreen> createState() => _CreateBookingScreenState();
}

class _CreateBookingScreenState extends ConsumerState<CreateBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isLoading = false;

  // Guest details
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  String? _selectedGuestId;

  // Booking details
  DateTime? _checkInDate;
  DateTime? _checkOutDate;
  int _numAdults = 2;
  int _numChildren = 0;
  String? _selectedPackageId;
  String? _selectedPackageName;
  double _basePrice = 0;
  String _source = 'PHONE';

  // Special requests
  final _specialRequestsController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _specialRequestsController.dispose();
    super.dispose();
  }

  Future<void> _createBooking() async {
    if (!_formKey.currentState!.validate()) return;
    if (_checkInDate == null) {
      _showError('Please select check-in date');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Create or find guest
      String guestId = _selectedGuestId ?? '';
      if (guestId.isEmpty) {
        final guestService = ref.read(guestServiceProvider);
        final guest = await guestService.findOrCreateGuest(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        );
        guestId = guest['id'] as String;
      }

      final totalAmount = _basePrice * _numAdults + (_basePrice * 0.5) * _numChildren;
      final taxAmount = totalAmount * 0.05; // 5% GST

      final booking = await ref.read(bookingServiceProvider).createBooking({
        'primary_guest_id': guestId,
        'package_id': null, // packages stored by name; no DB UUID yet
        'check_in_date': DateFormat('yyyy-MM-dd').format(_checkInDate!),
        'check_out_date': _checkOutDate != null ? DateFormat('yyyy-MM-dd').format(_checkOutDate!) : null,
        'num_adults': _numAdults,
        'num_children': _numChildren,
        'base_amount': totalAmount,
        'tax_amount': taxAmount,
        'total_amount': totalAmount + taxAmount,
        'source': _source,
        'special_requests': _specialRequestsController.text.trim().isEmpty
            ? null
            : _specialRequestsController.text.trim(),
        'status': 'INQUIRY',
        'payment_status': 'PENDING',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking ${booking.bookingNumber} created successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
        context.go('/bookings/${booking.id}');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AnjAppBar(title: 'New Booking'),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: Form(
          key: _formKey,
          child: Stepper(
            currentStep: _currentStep,
            onStepContinue: () {
              if (_currentStep < 3) setState(() => _currentStep++);
              else _createBooking();
            },
            onStepCancel: () {
              if (_currentStep > 0) setState(() => _currentStep--);
              else context.pop();
            },
            controlsBuilder: (context, details) {
              return Row(
                children: [
                  ElevatedButton(
                    onPressed: details.onStepContinue,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(120, 44)),
                    child: Text(_currentStep < 3 ? 'Next' : 'Create Booking'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: details.onStepCancel,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(80, 44)),
                    child: Text(_currentStep > 0 ? 'Back' : 'Cancel'),
                  ),
                ],
              );
            },
            steps: [
              // Step 1: Guest Info
              Step(
                title: const Text('Guest Info'),
                isActive: _currentStep >= 0,
                state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                content: _GuestInfoStep(
                  nameController: _nameController,
                  phoneController: _phoneController,
                  emailController: _emailController,
                  onGuestSelected: (id) => setState(() => _selectedGuestId = id),
                ),
              ),
              // Step 2: Booking Details
              Step(
                title: const Text('Booking Details'),
                isActive: _currentStep >= 1,
                state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                content: _BookingDetailsStep(
                  checkInDate: _checkInDate,
                  checkOutDate: _checkOutDate,
                  numAdults: _numAdults,
                  numChildren: _numChildren,
                  source: _source,
                  onCheckInChanged: (d) => setState(() => _checkInDate = d),
                  onCheckOutChanged: (d) => setState(() => _checkOutDate = d),
                  onAdultsChanged: (n) => setState(() => _numAdults = n),
                  onChildrenChanged: (n) => setState(() => _numChildren = n),
                  onSourceChanged: (s) => setState(() => _source = s),
                ),
              ),
              // Step 3: Package
              Step(
                title: const Text('Package'),
                isActive: _currentStep >= 2,
                state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                content: _PackageStep(
                  selectedPackageId: _selectedPackageId,
                  onPackageSelected: (id, name, price) => setState(() {
                    _selectedPackageId = id;
                    _selectedPackageName = name;
                    _basePrice = price;
                  }),
                ),
              ),
              // Step 4: Summary
              Step(
                title: const Text('Summary'),
                isActive: _currentStep >= 3,
                content: _SummaryStep(
                  guestName: _nameController.text,
                  guestPhone: _phoneController.text,
                  checkInDate: _checkInDate,
                  checkOutDate: _checkOutDate,
                  numAdults: _numAdults,
                  numChildren: _numChildren,
                  packageName: _selectedPackageName,
                  basePrice: _basePrice,
                  specialRequestsController: _specialRequestsController,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Steps ───────────────────────────────────────────────────────────────────────

class _GuestInfoStep extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final Function(String) onGuestSelected;

  const _GuestInfoStep({
    required this.nameController,
    required this.phoneController,
    required this.emailController,
    required this.onGuestSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Full Name *',
            prefixIcon: Icon(Icons.person_outline),
          ),
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          decoration: const InputDecoration(
            labelText: 'Mobile Number *',
            prefixIcon: Icon(Icons.phone_outlined),
            prefixText: '+91  ',
          ),
          validator: (v) => v == null || v.length != 10 ? 'Enter valid phone' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email (optional)',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
      ],
    );
  }
}

class _BookingDetailsStep extends StatelessWidget {
  final DateTime? checkInDate;
  final DateTime? checkOutDate;
  final int numAdults;
  final int numChildren;
  final String source;
  final Function(DateTime) onCheckInChanged;
  final Function(DateTime?) onCheckOutChanged;
  final Function(int) onAdultsChanged;
  final Function(int) onChildrenChanged;
  final Function(String) onSourceChanged;

  const _BookingDetailsStep({
    required this.checkInDate,
    required this.checkOutDate,
    required this.numAdults,
    required this.numChildren,
    required this.source,
    required this.onCheckInChanged,
    required this.onCheckOutChanged,
    required this.onAdultsChanged,
    required this.onChildrenChanged,
    required this.onSourceChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Check-in Date
        GestureDetector(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now().subtract(const Duration(days: 1)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date != null) onCheckInChanged(date);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: Row(
              children: [
                const Icon(Icons.login_rounded, color: AppTheme.primary),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Check-in Date *', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                    Text(
                      checkInDate != null ? DateFormat('d MMMM yyyy').format(checkInDate!) : 'Select date',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Check-out Date
        GestureDetector(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: checkInDate?.add(const Duration(days: 1)) ?? DateTime.now().add(const Duration(days: 1)),
              firstDate: checkInDate ?? DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            onCheckOutChanged(date);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: Row(
              children: [
                const Icon(Icons.logout_rounded, color: AppTheme.secondary),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Check-out Date', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                    Text(
                      checkOutDate != null ? DateFormat('d MMMM yyyy').format(checkOutDate!) : 'Day visit / Select date',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Guests count
        Row(
          children: [
            Expanded(
              child: _CounterField(
                label: 'Adults',
                value: numAdults,
                min: 1,
                onChanged: onAdultsChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CounterField(
                label: 'Children',
                value: numChildren,
                min: 0,
                onChanged: onChildrenChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Source
        DropdownButtonFormField<String>(
          value: source,
          decoration: const InputDecoration(
            labelText: 'Lead Source',
            prefixIcon: Icon(Icons.source_outlined),
          ),
          items: ['PHONE', 'WEBSITE', 'INSTAGRAM', 'WHATSAPP', 'GOOGLE', 'WALK_IN', 'REFERRAL']
              .map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' '))))
              .toList(),
          onChanged: (v) => v != null ? onSourceChanged(v) : null,
        ),
      ],
    );
  }
}

class _CounterField extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final Function(int) onChanged;

  const _CounterField({required this.label, required this.value, required this.min, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => value > min ? onChanged(value - 1) : null,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: value > min ? AppTheme.primary.withOpacity(0.1) : Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.remove, size: 16, color: value > min ? AppTheme.primary : AppTheme.textHint),
                ),
              ),
              Text('$value', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: () => onChanged(value + 1),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, size: 16, color: AppTheme.primary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PackageStep extends ConsumerWidget {
  final String? selectedPackageId;
  final Function(String, String, double) onPackageSelected;

  const _PackageStep({required this.selectedPackageId, required this.onPackageSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packages = [
      {
        'id': null,
        'name': 'Day Trip',
        'type': 'DAY_PICNIC',
        'adult_price': 1100.0,
        'kids_price': 750.0,
        'inclusions': 'Breakfast · Lunch · Evening Tea & Snacks',
        'timing': 'Check-in 9 AM · Check-out 5 PM',
        'note': 'Kids 0–4 yrs: Free',
      },
      {
        'id': null,
        'name': 'Tent Stay',
        'type': 'OVERNIGHT_STAY',
        'adult_price': 1600.0,
        'kids_price': 1100.0,
        'inclusions': 'Evening Tea · Dinner · Breakfast',
        'timing': 'Check-in 4 PM · Check-out 10 AM',
        'note': 'Kids 0–4 yrs: Free',
      },
      {
        'id': null,
        'name': 'Dormitory Stay',
        'type': 'OVERNIGHT_STAY',
        'adult_price': 2400.0,
        'kids_price': 1300.0,
        'inclusions': 'Breakfast · Lunch · Evening Tea · Dinner',
        'timing': 'Check-in 12 PM · Check-out 10:30 AM',
        'note': 'Kids 0–4 yrs: Free',
      },
      {
        'id': null,
        'name': 'Anjanpushp Villa',
        'type': 'OVERNIGHT_STAY',
        'adult_price': 2800.0,
        'kids_price': 1300.0,
        'inclusions': 'Breakfast · Lunch · Evening Tea · Dinner',
        'timing': 'Check-in 1 PM · Check-out 11 AM',
        'note': 'Max 12 guests · Kids 0–4 yrs: Free',
      },
      {
        'id': null,
        'name': 'Deluxe / Cottage Room',
        'type': 'OVERNIGHT_STAY',
        'adult_price': 3500.0,
        'kids_price': 1600.0,
        'inclusions': 'Breakfast · Lunch · Evening Tea · Dinner',
        'timing': 'Check-in 12 PM · Check-out 10:30 AM',
        'note': 'Kids 0–4 yrs: Free · +5% GST',
      },
      {
        'id': null,
        'name': 'Premium Room – Tikona View',
        'type': 'OVERNIGHT_STAY',
        'adult_price': 3500.0,
        'kids_price': 1700.0,
        'inclusions': 'Breakfast · Lunch · Evening Tea · Dinner',
        'timing': 'Check-in 12 PM · Check-out 10:30 AM',
        'note': 'Kids 0–4 yrs: Free · +5% GST',
      },
      {
        'id': null,
        'name': 'Premium Room – Deck Bed',
        'type': 'OVERNIGHT_STAY',
        'adult_price': 4000.0,
        'kids_price': 2200.0,
        'inclusions': 'Breakfast · Lunch · Evening Tea · Dinner',
        'timing': 'Check-in 12 PM · Check-out 10:30 AM',
        'note': 'Kids 0–4 yrs: Free · +5% GST',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '* 5% GST applicable on room stays. Booking confirmed on advance payment only.',
          style: TextStyle(fontSize: 11, color: AppTheme.textHint),
        ),
        const SizedBox(height: 12),
        ...packages.map((pkg) {
          final isSelected = selectedPackageId != null && selectedPackageId == pkg['name'];
          return GestureDetector(
            onTap: () => onPackageSelected(
              pkg['name'] as String,   // use name as key (no DB UUID yet)
              pkg['name'] as String,
              pkg['adult_price'] as double,
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary.withOpacity(0.08) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(
                  color: isSelected ? AppTheme.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                      color: isSelected ? AppTheme.primary : AppTheme.textHint,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pkg['name'] as String,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: isSelected ? AppTheme.primary : null,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${(pkg['adult_price'] as double).toStringAsFixed(0)} adult  ·  ₹${(pkg['kids_price'] as double).toStringAsFixed(0)} child (5–10)',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          pkg['inclusions'] as String,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.success),
                        ),
                        Text(
                          pkg['timing'] as String,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textHint),
                        ),
                        if (pkg['note'] != null)
                          Text(
                            pkg['note'] as String,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.accent),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _SummaryStep extends StatelessWidget {
  final String guestName;
  final String guestPhone;
  final DateTime? checkInDate;
  final DateTime? checkOutDate;
  final int numAdults;
  final int numChildren;
  final String? packageName;
  final double basePrice;
  final TextEditingController specialRequestsController;

  const _SummaryStep({
    required this.guestName,
    required this.guestPhone,
    required this.checkInDate,
    required this.checkOutDate,
    required this.numAdults,
    required this.numChildren,
    required this.packageName,
    required this.basePrice,
    required this.specialRequestsController,
  });

  @override
  Widget build(BuildContext context) {
    final subtotal = basePrice * numAdults + (basePrice * 0.5) * numChildren;
    final tax = subtotal * 0.05; // 5% GST
    final total = subtotal + tax;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryRow('Guest', guestName.isEmpty ? '—' : guestName),
        _SummaryRow('Phone', guestPhone.isEmpty ? '—' : '+91 $guestPhone'),
        _SummaryRow('Check-in', checkInDate != null ? DateFormat('d MMM yyyy').format(checkInDate!) : '—'),
        _SummaryRow('Check-out', checkOutDate != null ? DateFormat('d MMM yyyy').format(checkOutDate!) : 'Day Visit'),
        _SummaryRow('Guests', '$numAdults adults, $numChildren children'),
        if (packageName != null) _SummaryRow('Package', packageName!),
        const Divider(height: 24),
        _SummaryRow('Subtotal', '₹${subtotal.toStringAsFixed(0)}'),
        _SummaryRow('GST (5%)', '₹${tax.toStringAsFixed(0)}'),
        _SummaryRow('Total', '₹${total.toStringAsFixed(0)}', isBold: true),
        const SizedBox(height: 16),
        TextFormField(
          controller: specialRequestsController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Special Requests',
            hintText: 'Any dietary requirements, accessibility needs, etc.',
            prefixIcon: Icon(Icons.notes_outlined),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _SummaryRow(this.label, this.value, {this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: isBold
                ? Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.primary, fontWeight: FontWeight.bold)
                : Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}
