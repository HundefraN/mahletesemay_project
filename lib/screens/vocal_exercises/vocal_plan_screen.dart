import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mahlete_semay_project/models/vocal_plan_model.dart';
import 'package:mahlete_semay_project/providers/vocal_progress_provider.dart';

class VocalPlanScreen extends StatefulWidget {
  final VocalPlan initialPlan;
  const VocalPlanScreen({super.key, required this.initialPlan});

  @override
  State<VocalPlanScreen> createState() => _VocalPlanScreenState();
}

class _VocalPlanScreenState extends State<VocalPlanScreen> {
  final List<VocalExerciseStep> _allSteps = [];
  int _currentStepIndex = 0;

  @override
  void initState() {
    super.initState();
    _setupPlan();
  }

  void _setupPlan() {
    final progressProvider = Provider.of<VocalProgressProvider>(context, listen: false);

    _allSteps.clear();
    for (var routine in widget.initialPlan.routines) {
      _allSteps.addAll(routine.steps);
    }

    _currentStepIndex = progressProvider.progress[widget.initialPlan.title] ?? 0;

    if (_currentStepIndex >= _allSteps.length && _allSteps.isNotEmpty) {
      _currentStepIndex = _allSteps.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressProvider = Provider.of<VocalProgressProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialPlan.title),
        actions: [
          if (_currentStepIndex >= _allSteps.length && _allSteps.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                progressProvider.resetProgress(widget.initialPlan.title);
                setState(() {
                  _currentStepIndex = 0;
                });
              },
            ),
        ],
      ),
      body: _allSteps.isEmpty
          ? const Center(child: Text('Exercises for this plan are coming soon!'))
          : Stepper(
        currentStep: _currentStepIndex,
        onStepContinue: () {
          if (_currentStepIndex < _allSteps.length - 1) {
            progressProvider.completeStep(widget.initialPlan.title);
            setState(() => _currentStepIndex++);
          } else if (_currentStepIndex == _allSteps.length - 1) {
            progressProvider.completeStep(widget.initialPlan.title);
            setState(() => _currentStepIndex++);
          }
        },
        onStepCancel: () {
          if (_currentStepIndex > 0) {
            setState(() => _currentStepIndex--);
          }
        },
        steps: [
          ..._buildSteps(),
          if (_allSteps.isNotEmpty)
            Step(
              title: const Text('Complete!'),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Great job! You've completed today's routine."),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      progressProvider.resetProgress(widget.initialPlan.title);
                      setState(() => _currentStepIndex = 0);
                    },
                    child: const Text('Start Over'),
                  )
                ],
              ),
              state: _currentStepIndex >= _allSteps.length ? StepState.complete : StepState.indexed,
              isActive: _currentStepIndex >= _allSteps.length,
            ),
        ],
      ),
    );
  }

  List<Step> _buildSteps() {
    return _allSteps.asMap().entries.map((entry) {
      int index = entry.key;
      VocalExerciseStep step = entry.value;
      return Step(
        title: Text(step.title),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(step.description, style: const TextStyle(height: 1.5)),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.play_circle_fill_outlined),
                const SizedBox(width: 8),
                Text('Play Example (${step.durationInSeconds}s)'),
              ],
            ),
          ],
        ),
        isActive: _currentStepIndex == index,
        state: _currentStepIndex > index ? StepState.complete : StepState.indexed,
      );
    }).toList();
  }
}