# available-pets-consumer
Example consumer app to demonstrate 
[consumer-driven contract testing](https://www.martinfowler.com/articles/consumerDrivenContracts.html)
in action

The app is deployed to https://pets-consumer.herokuapp.com

A [Review App](https://devcenter.heroku.com/articles/github-integration-review-apps) is
created for each pull request.  The URL pattern for a review app is e.g.
https://available-pets-pr-123.herokuapp.com


## Workflow for consumer-driven changes to the provider API

Let's say that we want to add a new feature to show new pets in the petstore.

1. Have a collaborative story refinement session to come up with 
   [specification examples](https://gojko.net/2008/11/04/specifying-with-examples/), using 
   [example mapping](https://cucumber.io/blog/bdd/example-mapping-introduction/) for instance

2. [Write up the specification examples in Gauge](https://docs.gauge.org/writing-specifications.html).

   For our scenario, this could be something like:

```markdown
## Customers can see which pets are new in the pet store

* There is a pet named "doggie" new in the pet store
```

3. Write the [step implementation](https://docs.gauge.org/writing-specifications.html#step-implementations) to implement this new spec, e.g. for our [Taiko](https://taiko.dev/) JavaScript step implementation:

```js
step("There is a pet named <petName> new in the pet store", async function (petName) {
    await goto(`${process.env.WEB_URL}/new`);
    assert.ok(await text(petName).exists(0, 0));
});
```

4. Now we can run our new Gauge spec locally and of course it will fail, as we have not implemented the new feature yet:

  - start our Ruby web app locally: `rackup`
  - start a [Prism mock server](https://stoplight.io/open-source/prism/) locally, mocking the service provider based on
    the [provider](https://github.com/agilepathway/java-openapi-provider)'s OpenAPI spec:

    `prism mock https://github.com/agilepathway/java-gauge-openapi-example/raw/master/openapi.yaml --errors`

  - run the Gauge specs: `cd functional-tests && gauge run`

5. First step to make the failing spec pass is to add the new feature to our web app, e.g.

```ruby
get('/new') do
  new_pets.filter_map { |pet| "#{pet['name']}<br />" unless pet['name'].nil? }.prepend('<h2>New</h2>')
end

def new_pets
  get_json "#{petstore_url}pet/findByStatus?status=new"
end
```

6. Run the Gauge spec again. It will still fail, because the web app is requesting a pet status from the
provider's OpenAPI (`"#{petstore_url}pet/findByStatus?status=new"`) which the provider does not yet provide.

7. As we are consumer-driven, we (the consumer) will go ahead and make a change on the provider's OpenAPI spec,
   on a new feature branch in the provider's repository.

   - create a new feature branch in the provider's repository, matching the name of the feature branch that we
     are using in the consumer for our feature (`new-pets` in our example here).

     This requires having permission to create branches in the provider repo, which inside an organisation
     we recommend allowing.  If not, then the consumer would fork the provider repo.

   - Modify the 
     [provider's OpenAPI spec](https://github.com/agilepathway/java-openapi-provider/blob/master/openapi.yaml) with the proposed change, i.e. adding `new` to the list of defined statuses:

     ```
     enum:
       - available
       - pending
       - sold
       - new
     ```

8. Now we can run our Gauge spec again, but this time pointing our Prism mock server to our `new-pets` branch on the provider:

   `prism mock https://github.com/agilepathway/java-gauge-openapi-example/raw/new-pets/openapi.yaml --errors`

Now the spec passes :-)

9. Even though the provider has not implemented this feature yet (as it just the OpenAPI spec that has changed) we
   should now go ahead and create a pull request in our consumer repo.

   We have created
   [an actual pull request with the feature we have worked through above](https://github.com/agilepathway/available-pets-consumer/pull/38)
   as a working example.

   Our pull request triggers a CI/CD build which deploys a [Review App](https://devcenter.heroku.com/articles/github-integration-review-apps), where the provider service endpoint is a Prism mock which is created from
   the provider's OpenAPI spec on the provider's feature branch that we created, exactly the same as the Prism
   mock that we ran locally in the previous step above.

10. We would go ahead and merge the pull request.  One important thing to note is that as the provider has not yet
    implemented their side of the updated API, **we are not yet in a position to deploy our consumer to production**.
    One option would be to have hidden our feature behind a 
    [feature flag](https://trunkbaseddevelopment.com/feature-flags/).
    We don't *need* a feature flag though.  We also have the safety net of a build stage which tests our consumer
    web app against the *real* provider, rather than a mock.  This ensures that there's no danger of us breaking
    production by releasing our consumer before the provider.

11. The provider can now go ahead and implement their side of the updated (OpenAPI) contract, safe in the knowledge
    that as long as their implementation conforms to the changed OpenAPI spec then the consumer's needs will be met.
