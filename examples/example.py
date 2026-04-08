import random

THIRTY_START: int = 30
THIRTY_END: int = 39

class Person:
    def __init__(self, name: str, age: int) -> None:
        self.name: str = name
        self.age: int = age

    def __str__(self) -> str:
        return f"My name is {self.name} and I'm {self.age} years old!"

    def is_thirty(self) -> bool:
        return self.age >= THIRTY_START and self.age <= THIRTY_END

if __name__ == "__main__":
    john = Person("John", 25)
    print(john)

    doe = Person("Doe", 31)
    print(doe)

    years = [year for year in range(john.age)]
