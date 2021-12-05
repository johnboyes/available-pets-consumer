# available-pets-consumer
Example consumer app to demonstrate 
[consumer-driven contract testing](https://www.martinfowler.com/articles/consumerDrivenContracts.html)
in action

The app is deployed to https://pets-consumer.herokuapp.com

A [Review App](https://devcenter.heroku.com/articles/github-integration-review-apps) is
created for each pull request.  The URL pattern for a review app is e.g.
https://available-pets-pr-123.herokuapp.com

See also the companion [contract repo](https://github.com/agilepathway/available-pets-consumer-contract), which defines the
contract between this consumer repo and the provider.

## Workflow for consumer-driven changes to the provider API, amending the contract between consumer and provider

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

3. Write the [step implementation](https://docs.gauge.org/writing-specifications.html#step-implementations) to 
   implement this new spec, e.g. for our [Taiko](https://taiko.dev/) JavaScript step implementation:

   ```js
   step("There is a pet named <petName> new in the pet store", async function (petName) {
      await goto(`${process.env.WEB_URL}/new`);
      assert.ok(await text(petName).exists(0, 0));
   });
   ```

4. Now we can run our new Gauge spec locally and of course it will fail, as we have not implemented the new feature yet:

  - start our Ruby web app locally: `rackup`
  - start a [Prism mock server](https://stoplight.io/open-source/prism/) locally, mocking the service provider based on
    the [contract repo](https://github.com/agilepathway/available-pets-consumer-contract)'s OpenAPI spec:

    `prism mock https://github.com/agilepathway/available-pets-consumer-contract/raw/master/openapi.yaml --errors`

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
contract's OpenAPI (`"#{petstore_url}pet/findByStatus?status=new"`) which the contract does not yet specify.

7. As we are consumer-driven, we (the consumer) will go ahead and make a change on the contract's OpenAPI spec,
   on a new feature branch in the contract repo's repository.

   - create a new feature branch in the contract repo's repository, matching the name of the feature branch that we
     are using in the consumer for our feature (`new-pets-status` in our example here).

   - Modify the 
     [contract repo's OpenAPI spec](https://github.com/agilepathway/available-pets-consumer-contract/blob/master/openapi.yaml) with the proposed change, i.e. adding `new` to the list of defined statuses:

     ```
     enum:
       - available
       - pending
       - sold
       - new
     ```

8. Now we can run our Gauge spec again, but this time pointing our Prism mock server to our `new-pets-status` branch on the provider:

   `prism mock https://github.com/agilepathway/java-gauge-openapi-example/raw/new-pets-status/openapi.yaml --errors`

Now the spec passes :-)

9. Even though the provider has not implemented this feature yet (as it just the OpenAPI spec that has changed) we
   should now go ahead and create a pull request in our consumer repo.

   We have created
   [an actual pull request with the feature we have worked through above](https://github.com/agilepathway/available-pets-consumer/pull/44)
   as a working example.

   Our pull request triggers a CI/CD build which deploys a [Review App](https://devcenter.heroku.com/articles/github-integration-review-apps), where the provider service endpoint is a Prism mock which is created from
   the contract repo's OpenAPI spec on the contract repo's feature branch that we created, exactly the same as the
   Prism mock that we ran locally in the previous step above.

10. It is important that the contract repo also has always-up-to-date specifications which define the contract.
    Our definition of the contract is the Gauge specifications on the contract repo, together with the OpenAPI spec
    itself.  So we as the consumer should also add a specification in the *contract* repo (on the same feature branch that we created for the OpenAPI spec modification), e.g.

    ```markdown
    ## Customers can see which pets are new in the pet store

    * There is a pet named "doggie" new in the pet store
    ```

    Note that this spec is identical to the spec we created earlier in our consumer repo.  This is a good thing as it
    describes the same consistent API contract in both the consumer and provider (it's not a disaster if the specs
    have slightly different wording due to step implementation differences, but it's a good goal to keep them the same
    or as close to the same as possible).

    The consumer team should go ahead and add the step implementation for this spec in the contract repo, on the same
    feature branch where the OpenAPI spec was amended.  The step implementation on the contract repo is a 
    black-box API test using Prism, so implementing it does not require any knowledge of the internals of the provider
    application.  The contract repo is jointly owned by the consumer and the provider.  This is a nice instance of
    using [innersource](https://resources.github.com/whitepapers/introduction-to-innersource/) principles.  When the
    consumer is driving the change (which is the case in our example here and also what we want to happen, normally),
    then it's natural that the consumer should also update the contract (including the Gauge spec and step implementation as well as the OpenAPI spec).

    Have a look at 
    [the `new-pets-status` branch in the provider](https://github.com/agilepathway/java-openapi-provider/tree/new-pets-status) 
    and you can see these changes added by the consumer in the most recent commits there.

11. If we try to merge the pull request in our own consumer repo now, we will not be able to.  This is because we have
    a check in our CI/CD pipeline which needs the Gauge specs in the consumer repo to pass when running against the
    latest OpenAPI spec in the _trunk_ of the contract repo.  So we first have to create a merge request on the
    _contract_ repo and merge it to trunk, _before_ we can merge our consumer repo's merge request.  This is all a good thing, as it mandates the important principle that the consumer repo must always satisfy the latest contract (i.e.
    the latest contract in the contract repo's trunk).

12. So we (the consumer) now create a merge request on the _contract_ repo.  The provider should review the merge
    request and when both provider and consumer are happy with the merge request then it can be merged.  Bear in mind
    that the provider does not need to have even started the work that they will need to do in due course to add the
    new functionality on their own provider repo.

13. With the contract repo's merge request having now been merged, the consumer is now able to merge their merge
    request on their own consumer repo.  This means we have proper 
    [Trunk-Based Development](https://trunkbaseddevelopment.com/), i.e. the consumer has been able to integrate
    their change into trunk without needing to wait for the provider to implement their change :sunglasses:

14. The provider can also go ahead and implement their side of the updated (OpenAPI) contract, safe in the knowledge
    that as long as their implementation conforms to the changed OpenAPI spec then the consumer's needs will be met.

15. If the consumer tries to deploy to an integrated environment (pre-production is the first integrated environment
    in our example CI/CD pipeline here, followed afterwards by production), they will not be able to deploy until the
    provider has deployed their change to that environment.  This is essential as we want to avoid at all costs having
    an incompatible consumer and provider in an integrated environment.  We ensure that doesn't happen by having a
    "Can I deploy" stage in our CI/CI pipeline.  This Can I deploy stage runs the Gauge specs on the contract repo,
    using the specific commit on the contract repo that is associated with the consumer commit that we want to deploy.
    The Gauge specs run against the provider (using Prism's 
    [validation proxy](https://meta.stoplight.io/docs/prism/docs/guides/03-validation-proxy.md) mode), making sure that
    we can only deploy if the contract is satisfied against the provider.


## Benefits of this approach

1. Collaborative - consumers, solution architects, developers, testers, analysts, Product Owner all have a natural interest in being involved.  This is a great silo breaker.
2. [Shift Left](https://devops.com/devops-shift-left-avoid-failure/) - enables testing of APIs before implementation has started
3. [Design-first APIs](https://tyk.io/moving-api-design-first-agile-world/)
   - [Development teams can work in parallel](https://swagger.io/resources/articles/adopting-an-api-first-approach/#development-teams-can-work-in-parallel--3)
   - [Reduces the cost of developing apps](https://swagger.io/resources/articles/adopting-an-api-first-approach/#reduces-the-cost-of-developing-apps-4)
   - [Increases the speed to market](https://swagger.io/resources/articles/adopting-an-api-first-approach/#increases-the-speed-to-market-5)
   - [Ensures good developer experiences](https://swagger.io/resources/articles/adopting-an-api-first-approach/#ensures-good-developer-experiences-6)
   - [Reduces the risk of failure](https://swagger.io/resources/articles/adopting-an-api-first-approach/#reduces-the-risk-of-failure-7)
4. [Specification by Example](https://gojko.net/2008/11/04/specifying-with-examples/)
   - Shared understanding between all parties
   - [Living documentation](https://www.infoq.com/articles/book-review-living-documentation/), providing a single source of truth. This API documentation stays up to date because it is executable, and is only written in one place (rather than analysts, developers and testers all writing their own separate documentation.)
5. API [black box testing](https://resources.whitesourcesoftware.com/blog-whitesource/black-box-testing)
   - provides great test coverage
6. Having a Review App on each pull request allows the development team and Product Owner to review each feature straightaway
   and to flag any issues *before* the feature is merged (rather than waiting till a much later UAT phase).