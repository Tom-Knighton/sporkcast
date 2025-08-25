//
//  RecipeMock.swift
//  API
//
//  Created by Tom Knighton on 25/08/2025.
//

public class RecipeMockBuilder {
    
    var title: String = "Chicken Katsu Curry"
    var description: String? = "One of the best fakeaway creations! My Wagamama inspired chicken katsu curry. With the crispy breaded chicken being baked, it’s lower in calories and just as delicious."
    var author: String? = "Mimi Harrison"
    var imageUrl: String? = "https://beatthebudget.com/wp-content/uploads/2020/07/chicken-katsu-curry-featured-image-scaled.jpg"
    var minutesToPrepare: Double = 5
    var minutesToCook: Double = 30
    var minutes: Double = 35
    var serves: String? = "6"
    var ingredients: [String] = [
        "650 g chicken breasts ((£4.00))",
        "70 g to 140g (6oz) panko breadcrumbs (if double dipping) ((£1.25))",
        "2  egg ( (£1.39/12)=(£0.24))",
        "1 tbsp ginger, peeled &amp; grated ((£0.55))",
        "2  onions, diced ((£0.65/3)=(£0.22))",
        "1  carrot, thinly sliced ((£0.09))",
        "3 cloves of garlic, minced ((£0.69/3)=(£0.23))",
        "600 ml chicken stock",
        "1 tbsp honey/brown sugar",
        "1.5 tbsp curry powder",
        "½ tsp turmeric",
        "1 tbsp coconut oil",
        "2 tbsp rapeseed oil",
        "1.5 tbsp soy sauce",
        "2 tbsp flour",
        "Other 300g white/brown rice ((£1.50/5X3)=(£0.90))",
        "Spring onions to garnish ((£0.50))",
        "Chilli flakes"
    ]
    
    var tags: [String] = ["Asian", "Main Course", "Japanese"]
    var url: String = "https://beatthebudget.com/recipe/chicken-katsu-curry/#recipe"
    var stepSections: [RecipeStepSection] = [
        .init(title: nil, steps: [
            .init(step: "Start by adding the onion & carrots into a deep non-stick frying pan along with the coconut oil. Gently fry on a medium/ low heat for around 5 minutes. Season with salt."),
            .init(step: "After this time, add the minced garlic, curry powder, ginger, turmeric, honey, soy sauce and flour with a splash of the chicken stock. Gently fry for another minute before gradually adding all of the chicken stock. Reduce to a simmer and set the timer for 20 minutes."),
            .init(step: "Meanwhile, prepare the chicken by slicing the 3 breasts along the width to create 6 thin chicken pieces. Start the crispy chicken conveyor belt by rolling it in flour, then the beaten egg and finally in the breadcrumbs. If you want the crispiest chicken, dip into the egg and breadcrumbs one more time (may require more breadcrumbs)."),
            .init(step: "Drizzle half of the rapeseed oil onto a large baking try and add the battered chicken. Then drizzle the remaining rapeseed oil over the top to coat. Pop in the oven, timer set to 12 minutes to rotate and cook for a further 12 minutes on the other side."),
            .init(step: "In the meantime, cook the rice according to packet instructions"),
            .init(step: "After 20 minutes, the katsu sauce should have thickened slightly so it’s ready to blend.  Slice the chicken diagonally for that wagamama look and serve up with a portion of rice, a ladle of the sauce and the optional sliced spring onion & chilli flakes.")
        ])
    ]
    var ratings: RecipeRatings = .init(overallRating: 4.41, reviews: [
        .init(text: "Curry recipe was good but turned out a bit too salty. Chicken part does not work at all it ended up making the chicken soggy so i had to fry it in a pan..."),
        .init(text: "family absolutely loved this!"),
        .init(text: "Trying this tomorrow night sounds delicious.👍"),
        .init(text: "Absolutely lovely"),
        .init(text: "Great recipe! I substituted the chicken with slices of Tofu, for a delicious vegetarian alternative."),
        .init(text: "Absolutely fantastic, I did the chicken in the air fryer after putting on a sprinkling of olive oil and it was super crispy. I made the sauce the night before as my friend suggested too. Will definitely make again.")
    ])
    
    public func withTitle(_ title: String) -> RecipeMockBuilder {
        self.title = title
        return self
    }
    
    public func withDescription(_ description: String?) -> RecipeMockBuilder {
        self.description = description
        return self
    }
    
    public func withAuthor(_ author: String?) -> RecipeMockBuilder {
        self.author = author
        return self
    }
    
    public func withImageUrl(_ url: String?) -> RecipeMockBuilder {
        self.imageUrl = url
        return self
    }
    
    public func withMinutes(_ totalMinutes: Double, preparationMinutes: Double, cookMinutes: Double) -> RecipeMockBuilder {
        self.minutes = totalMinutes
        self.minutesToCook = cookMinutes
        self.minutesToPrepare = preparationMinutes
        return self
    }
    
    public func withServes(_ serves: String?) -> RecipeMockBuilder {
        self.serves = serves
        return self
    }
    
    public func withUrl(_ url: String) -> RecipeMockBuilder {
        self.url = url
        return self
    }
    
    public func withIngredient(_ ingredient: String) -> RecipeMockBuilder {
        self.ingredients.append(ingredient)
        return self
    }
    
    public func withIngredients(_ ingredients: [String]) -> RecipeMockBuilder {
        self.ingredients = ingredients
        return self
    }
    
    public func withTags(_ tags: [String]) -> RecipeMockBuilder {
        self.tags = tags
        return self
    }
    
    public func withStepSection(_ stepSection: RecipeStepSection) -> RecipeMockBuilder {
        self.stepSections.append(stepSection)
        return self
    }
    
    public func withSteps(_ stepSections: [RecipeStepSection]) -> RecipeMockBuilder {
        self.stepSections = stepSections
        return self
    }
    
    public func withRatings(_ ratings: RecipeRatings) -> RecipeMockBuilder {
        self.ratings = ratings
        return self
    }
    
    public func build() -> Recipe {
        Recipe(title: title, description: description, author: author, imageUrl: imageUrl, minutesToPrepare: minutesToPrepare, minutesToCook: minutesToCook, totalMins: minutes, serves: serves, url: url, ingredients: ingredients, tags: tags, stepSections: stepSections, ratings: ratings)
    }
}
