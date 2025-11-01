import 'package:flutter/material.dart';
import 'package:bloc/bloc.dart';

void main() {
  final cubitA = CounterCubit(0); // state starts at 0
  final cubitB = CounterCubit(10); // state starts at 10
  //runApp(const MainApp());
  final cubit = CounterCubit(0);
  print(cubit.state); // 0
  cubit.increment();
  print(cubit.state); // 1
  cubit.close();
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Hello World!'),
        ),
      ),
    );
  }
}


class CounterCubit extends Cubit<int> {
  CounterCubit(int initialState) : super(initialState);

  void increment() => emit(state + 1);
}
